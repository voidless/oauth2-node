URL  = require 'url'
util = require './util'
OAuth2Error = require './error'

module.exports = class Gateway extends require('./options')
  constructor: ->
    super

  middleware: ->
    clientID = @options.clientID
    throw new Error "Please provide 'clientID' option" unless clientID
    clientSecret = @options.clientSecret
    throw new Error "Please provide 'clientSecret' option" unless clientSecret

    dialogUrl = util.parse_url(@options.dialogUrl or @dialog_url)
    throw new Error "Please provide 'dialogUrl' option or implement 'dialog_url' method" unless dialogUrl?.hostname
    dialogQuery = dialogUrl.query or= {}
    dialogQuery.scope = util.normalize_scope(@options.scope).join(@options.scopeSeparator || ' ')
    dialogQuery.client_id = clientID
    dialogQuery.response_type = 'code'

    tokenUrl = util.parse_url(@options.tokenUrl or @token_url)
    throw new Error "Please provide 'tokenUrl' option or implement 'token_url' method" unless tokenUrl?.hostname
    tokenQuery = tokenUrl.query or= {}
    tokenQuery.grant_type = 'authorization_code'
    tokenQuery.client_id = clientID
    tokenQuery.client_secret = clientSecret

    profile_url = @options.profileUrl or @profile_url
    throw new Error "Please provide profileUrl" unless profile_url

    parse_profile = @options.parseProfile or @parse_profile
    throw new Error "Please provide function 'parseProfile' or implement 'parse_profile' method" unless parse_profile
    throw new Error "Provided parseProfile is not a function" unless typeof parse_profile == 'function'
    
    displayType = @options.display
    successPath = @options.successPath
    errorPath   = @options.errorPath
    sessionKey  = @options.sessionKey

    onError = (res, next, error) ->
      if errorPath
        res.redirect errorPath
      else
        error = new OAuth2Error error if typeof error == 'string'
        next error

    onSuccess = (req, res, next, oauth, profile) ->
      oauth.profile = profile
      if sessionKey && session = req.session
        session[sessionKey] = oauth
        session.save() if successPath
      else
        req.oauth = oauth
      if successPath
        res.redirect successPath
      else
        next()

    fetchProfile = (req, res, next, oauth) ->
      util.perform_request util.parse_url(profile_url, oauth), (error, data) ->
        return onError(res, next, error or 'Failed to get user profile') unless data
        parse_profile data, (error, profile) ->
          return onError(res, next, error or 'Bad profile data received') unless profile
          onSuccess req, res, next, oauth, profile

    (req, res, next) ->
      url = URL.parse(req.url, true)
      query = url.query
      
      # error response from provider
      if query.error
        return onError res, next, new OAuth2Error query.error_description, code:query.error, reason:query.error_reason

      # authorize with access_token
      if query.access_token
        return fetchProfile req, res, next, query

      fullUrl = URL.format
        protocol: if req.connection.encrypted then 'https' else 'http'
        hostname: req.headers.host
        pathname: url.pathname

      # authorization code from provider, exchange it to access_token and fetch profile
      if query.code
        tokenQuery.code = query.code
        tokenQuery.redirect_uri = fullUrl
        return util.perform_request tokenUrl, (error, data) =>
          oauth = util.parse_response_data data if data
          return onError(res, next, error or 'Failed to get access token') unless oauth
          return onError(res, next, oauth.error) if oauth.error
          fetchProfile req, res, next, oauth

      # We don't have any expected parameters from provider, just redirect client to provider's authorization dialog page
      dialogQuery.display = displayType or util.dialog_display_type(req)
      dialogQuery.redirect_uri = fullUrl
      res.redirect URL.format dialogUrl
