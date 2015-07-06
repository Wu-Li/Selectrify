MAPJS.URLHelper =
  urlPattern: /(https?:\/\/|www\.)[\w-]+(\.[\w-]+)+([\w.,!@?^=%&amp;:\/~+#-]*[\w!@?^=%&amp;\/~+#-])?/i
  containsLink: (text) ->
    MAPJS.URLHelper.urlPattern.test text

  getLink: (text) ->
    url = text.match(MAPJS.URLHelper.urlPattern)
    if url and url[0]
      url = url[0]
      if !/https?:\/\//i.test(url)
        url = 'http://' + url
    url

  stripLink: (text) ->
    text.replace MAPJS.URLHelper.urlPattern, ''
