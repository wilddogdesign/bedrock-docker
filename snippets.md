# WDD Snippers

Fancy starting a bit quicker?

## WP: Linking in CSS

### Puppy style template

In your Wordpress functions.php

```
$static = get_stylesheet_directory_uri() . '/static/';
$context['static'] = $static;

$context['css'] = $static . 'css/' . $cssFile;
$context['criticalCss'] = file_get_contents(dirname(__FILE__) . '/static/css/critical.css');
```

### Whippet style template

```
$static = get_stylesheet_directory_uri() . '/static/';
$context['static'] = $static;

$cssFiles = glob('app/themes/bedrock-theme/static/css/main-*.css');

foreach($cssFiles as $key => $filename) {
  if(strpos($filename, "critical")) {
    $critical_file_path = $cssFiles[$key];
    unset($cssFiles[$key]);
  }
}

$fileLocation = array_values($cssFiles)[0];
$cssFile = substr($fileLocation, strrpos($fileLocation, '/') + 1);
$context['css'] = $static . 'css/' . $cssFile;
$context['criticalCss'] = str_replace('../',get_stylesheet_directory_uri() . '/static/',file_get_contents($critical_file_path));
```
