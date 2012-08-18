zeroPad = (n) -> if n < 10 then '0' + n else n

module.exports = class Strategy extends require('../strategy')
  constructor: ->
    super
    profileFields = 'uid,first_name,last_name,nickname,screen_name,sex,bdate,photo'
    @regUrl 'dialog', protocol:'http', hostname:'oauth.vk.com', pathname:'/authorize'
    @regUrl 'token', protocol:'https', hostname:'oauth.vk.com', pathname:'/access_token'
    @regUrl 'profile', (data) -> @apiUrl 'users.get',   uid:data.user_id, fields:profileFields, access_token:data.access_token
    @regUrl 'friends', (data) -> @apiUrl 'friends.get', uid:data.user_id, fields:profileFields, access_token:data.access_token

  apiUrl: (method, query) -> protocol:'https', hostname:'api.vk.com', pathname:"/method/#{method}", query:(query or {})

  parseProfile: (resp, done) ->
    data = if resp.constructor == Array then resp[0] else resp
    dateParts = data.bdate?.split '.' if /^\d+\.\d+(\.\d+)?$/.test data.bdate
    if dateParts
      bday = "#{zeroPad dateParts[1]}/#{zeroPad dateParts[0]}"
    if dateParts?[2]
      bdate = new Date dateParts[2], dateParts[1]-1, dateParts[0], 12
      bday += "/#{zeroPad dateParts[2]}"
    done null,
      provider: 'vk'
      id: data.uid
      gender: switch data.sex
        when 1 then "female"
        when 2 then "male"
        else "undisclosed"
      name:
        familyName: data.last_name
        givenName: data.first_name
      bdate: bdate
      bday: bday
      displayName: if data.nickname then "#{data.first_name} #{data.nickname} #{data.last_name}" else "#{data.first_name} #{data.last_name}"
      profileUrl: "http://vk.com/id#{data.uid}"
      photo: data.photo

  validateResponse: (resp, done) ->
    return done resp.error if resp.error
    done null, resp.response
