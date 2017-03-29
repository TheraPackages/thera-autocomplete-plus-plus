fs = require 'fs'
path = require 'path'
CSON = require 'season'

isDirectory = (p)->
  stat = fs.lstatSync(p)
  if stat && stat.isDirectory()
    return on
  return off


module.exports =
class MiniDocument
  mini_doc: null

  constructor: ->

  load: ->
    # 确保存在 configDirPath目录
    if isDirectory atom.configDirPath
      docPath = path.join atom.configDirPath, 'doc'

      # 如果docs不存在，就建立一个
      if not fs.existsSync docPath
        fs.mkdirSync docPath

      # 如果存在但是不是目录就删掉重新建目录
      if not isDirectory docPath
        fs.unlinkSync docPath
        fs.mkdirSync docPath

      docFile = path.join docPath, 'weex-mini-document.cson'
      if fs.existsSync docFile
        @mini_doc = CSON.readFileSync docFile
        console.log @mini_doc

        for k, v of @mini_doc
          console.log k, v

      # WeexDoc = CSON.readFileSync (path.join doc, 'weex-mini-document.cson')
      # docJsonFilePath = path.join doc, 'weex-doc.json'
