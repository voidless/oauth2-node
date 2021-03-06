module.exports = class Strategy extends require('../strategy')
  constructor: ->
    super
    profileFields = 'id,first_name,last_name,middle_name,username,name,gender,birthday,link,email,picture'
    @regUrl 'dialog', protocol:'http', hostname:'facebook.com', pathname:'/dialog/oauth'
    @regUrl 'token',  @graphUrl 'oauth/access_token'
    @regUrl 'profile', (data) -> @graphUrl 'me', fields:profileFields, access_token:data.access_token
    @regUrl 'friends', (data) -> @graphUrl 'me/friends', fields:profileFields, access_token:data.access_token

  graphUrl: (method, query) -> protocol:'https', hostname:'graph.facebook.com', pathname:"/#{method}", query:(query or {})

  parseProfile: (data, done) ->
    dateParts = data.birthday?.split '/' if /^\d+\/\d+\/\d+$/.test data.birthday
    done null,
      provider: 'facebook'
      id: data.id
      username: data.username
      displayName: data.name
      name:
        familyName: data.last_name
        givenName: data.first_name
        middleName: data.middle_name
      bdate: new Date dateParts[2], dateParts[0]-1, dateParts[1], 12 if dateParts
      bday: data.birthday
      gender: data.gender
      profileUrl: data.link
      emails: [value: data.email] if data.email
      photo: data.picture?.data?.url

  validateResponse: (resp, done) ->
    return done resp.error if resp.error
    done null, (resp.data or resp)
