"use strict";

const plan = require("flightplan");
const project = "bedrock";

var user = "Someone";

const themeName = "bedrock-theme";

const args = {
  critical: process.argv.indexOf("--no-critical-css") > -1 ? false : true,
  minify: process.argv.indexOf("--no-minification") > -1 ? false : true
};

const linkedFiles = ["bedrock/.env", "bedrock/web/.htaccess"];

const linkedDirs = ["bedrock/web/app/uploads"];

const linkedAssets = [
  "templates/dist/assets/css",
  "templates/dist/assets/js",
  "templates/dist/assets/icons",
  "templates/dist/assets/favicons",
  "templates/dist/assets/fonts",
  "templates/dist/assets/images",
  "templates/dist/assets/json",
];

const remoteTmpFolder = "/tmp";

// configuration for staging (development)
plan.target("staging", {
  branch: "staging",
  host: "wilddogdevelopment.com",
  projectRoot: `/var/www/${project}`,
  username: "deployer",
  agent: process.env.SSH_AUTH_SOCK,
  maxDeploys: 5,
  port: 2022
});

// configuration for production
plan.target("production", {
  branch: "master",
  host: "domain.com",
  port: "18765",
  projectRoot: `/path/to/site/root`,
  username: "user",
  agent: process.env.SSH_AUTH_SOCK,
  maxDeploys: 5
});

const versionDir = `${project}-${new Date().getTime()}`;

// run commands on localhost
plan.local("deploy", local => {
  // Check if repo is dirty
  const repoStatus = local.exec('test -z "$(git status --porcelain)"', {
    failsafe: true
  });

  local.log("Code: " + repoStatus.code);
  if (repoStatus.code !== 0) {
    local.log("Your local repository is dirty. Y u no commit?");
    plan.abort();
  }

  // Check if branch is synced
  const branchName = local.git("rev-parse --abbrev-ref HEAD").stdout.trim();
  const localRefHash = local.git("rev-parse HEAD").stdout.trim();
  const remoteRefHash = local
    .git(`ls-remote origin -h refs/heads/${branchName} | cut -f1`)
    .stdout.trim();

  if (localRefHash != remoteRefHash) {
    local.log(
      "Your local repository is not up-to-date. Sync with remote first."
    );
    plan.abort();
  }

  // Check if the right branch
  if (branchName != plan.runtime.hosts[0].branch) {
    local.log(
      `You can't deploy anything else than ${plan.runtime.hosts[0].branch} to ${
        plan.runtime.target
      }.`
    );
    plan.abort();
  }

  user = local.exec("git config user.name");

  local.log("Run templates build");
  local.exec(
    `cd ../templates && npm run build:bedrock -- ${
      args.minify ? "" : " --no-minification"
    } ${args.critical ? "" : " --no-critical-css"}`
  );

  local.log("Run composer");
  local.exec(
    `cd ../bedrock && composer install --no-dev --prefer-dist --no-interaction --quiet --optimize-autoloader`
  );

  local.log("Archive the needed folders");
  // local.exec(`mkdir -p .tmp/`);
  local.exec(
    `cd ../ && tar --exclude='./bedrock/web/app/uploads' -czf deploy/${versionDir}.tar.gz templates/dist/ bedrock/`
  );

  local.log("Copy files to remote hosts");
  // rsync files to all the target's remote hosts
  let tarFile = `${versionDir}.tar.gz`;
  local.transfer(tarFile, `${remoteTmpFolder}/${versionDir}.tar.gz`);
  local.exec(`rm -f ${versionDir}.tar.gz`);
});

// run commands on the target's remote hosts
plan.remote("deploy", remote => {
  remote.hostname();

  remote.log("Create needed folders");
  remote.exec(
    `mkdir -p ${remote.runtime.projectRoot}/shared ${
      remote.runtime.projectRoot
    }/releases/${versionDir}`
  );

  remote.log("Extract files");
  remote.exec(
    `tar -xzvf ${remoteTmpFolder}/${versionDir}.tar.gz -C ${
      remote.runtime.projectRoot
    }/releases/${versionDir} --exclude="._*" && rm -f ${remoteTmpFolder}/${versionDir}.tar.gz`
  );

  remote.log("Create linked folders");
  linkedDirs.forEach(dir => {
    remote.exec(
      `rm -Rf ${remote.runtime.projectRoot}/releases/${versionDir}/${dir}`
    );
    remote.exec(`mkdir -p ${remote.runtime.projectRoot}/shared/${dir}`);
  });

  remote.log("Link assets");
  linkedAssets.forEach(asset => {
    remote.exec(
      `cd ${
        remote.runtime.projectRoot
      }/releases/${versionDir}/bedrock/web/app/themes/${themeName}/static/ && rm -Rf ${asset
        .split("/")
        .pop()} && ln -snf ${
        remote.runtime.projectRoot
      }/releases/${versionDir}/${asset}`
    );
  });

  remote.log("Link all the things");
  linkedFiles.concat(linkedDirs).forEach(link => {
    const folder = link
      .split("/", -1)
      .reduce((pre, cur, i, array) =>
        i < array.length - 1 ? `${pre}/${cur}` : `${pre}/`
      );
    remote.exec(
      `cd ${
        remote.runtime.projectRoot
      }/releases/${versionDir}/${folder} && ln -snf ${
        remote.runtime.projectRoot
      }/shared/${link}`
    );
  });

  remote.log("Point to current version");
  remote.exec(
    `cd ${remote.runtime.projectRoot} && rm -f current && ln -snf ${
      remote.runtime.projectRoot
    }/releases/${versionDir} current`
  );

  if (remote.runtime.maxDeploys > 0) {
    remote.log("Cleaning up old deploys...");
    remote.exec(
      "rm -rf `ls -1dt " +
        remote.runtime.projectRoot +
        "/releases/* | tail -n +" +
        (remote.runtime.maxDeploys + 1) +
        "`"
    );
  }

  // Restart php on staging server
  if (["staging", "development"].includes(plan.runtime.target)) {
    remote.log("Update PHP");
    remote.exec("sudo systemctl reload php7.3-fpm");
  } else {
    remote.log("Remote In Production");
  }

  remote.exec(
    `curl -X POST --data-urlencode 'payload={"channel": "#deployments", "username": "deploybot", "text": "${
      user.stdout
    } has just deployed *${project}* project to <http://${
      remote.runtime.host
    }|its *production* server>", "icon_emoji": ":shipit:"}' https://hooks.slack.com/services/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`
  );
});

plan.remote("rollback", remote => {
  remote.hostname();

  remote.with(`cd ${remote.runtime.projectRoot}`, () => {
    let command = remote.exec("ls -1dt versions/* | head -n 2");
    let versions = command.stdout.trim().split("\n");

    if (versions.length < 2) {
      return remote.log("No version to rollback to");
    }

    let lastVersion = versions[0];
    let previousVersion = versions[1];

    remote.log(`Rolling back from ${lastVersion} to ${previousVersion}`);

    remote.exec(`ln -fsn ${previousVersion} current`);
    // remote.exec('chown -R ' + remote.runtime.ownerUser + ':' + remote.runtime.ownerUser + ' current');

    remote.exec(`rm -rf ${lastVersion}`);
  });
});
