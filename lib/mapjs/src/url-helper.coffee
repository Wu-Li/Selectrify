MAPJS.URLHelper =
  urlPattern: /(https?:\/\/|www\.)[\w-]+(\.[\w-]+)+([\w.,!@?^=%&amp;:\/~+#-]*[\w!@?^=%&amp;\/~+#-])?/i
  containsLink: (text) ->
    'use strict'
    MAPJS.URLHelper.urlPattern.test text
  getLink: (text) ->
    'use strict'
    url = text.match(MAPJS.URLHelper.urlPattern)
    if url and url[0]
      url = url[0]
      if !/https?:\/\//i.test(url)
        url = 'http://' + url
    url
  stripLink: (text) ->
    'use strict'
    text.replace MAPJS.URLHelper.urlPattern, ''
