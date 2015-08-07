module.exports =
  parsers:
    coffee: require('./coffeescript').parse
    js: require('./javascript').parse
    html: require('./html').parse
    css: require('./less').parse
    less: require('./less').parse

  deparsers:
    coffee: require('./coffeescript').deparse
    js: require('./javascript').deparse
    html: require('./html').deparse
    css: require('./less').deparse
    less: require('./less').deparse
