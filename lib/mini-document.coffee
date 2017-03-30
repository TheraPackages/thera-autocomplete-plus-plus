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

  weexDoc: {}

  constructor: ->

  load: ->
    # 确保存在 configDirPath目录
    if isDirectory atom.configDirPath
      docPath = path.join atom.configDirPath, 'doc'

      # 如果docs不存在，则创建
      if not fs.existsSync docPath
        fs.mkdirSync docPath

      # 如果存在但是不是目录就删掉重新建目录
      if not isDirectory docPath
        fs.unlinkSync docPath
        fs.mkdirSync docPath

      docConfigPath = path.join docPath, 'config.cson'
      config = {}
      if fs.existsSync docConfigPath
        config = CSON.readFileSync docConfigPath
      else
        config =
          ".source.we": "weex-mini-document.cson"
          ".source.lua": "lua-mini-document.cson"
      for key, value of config
        docFile = path.join docPath, value
        if fs.existsSync docFile
          @weexDoc[key] = CSON.readFileSync docFile

  ###
  # Document text provider
  # @param cope: such as .source.we .source.lua
  # @param name: such as suggestion list text
  # @return the selected doc
  ###
  getMiniDocumentSection: (scope, name) ->
    @weexDoc[scope]?[name]
