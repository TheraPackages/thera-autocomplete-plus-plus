fs = require 'fs'
path = require 'path'
CSON = require 'season'
Nageland = require 'nageland'

isDirectory = (p) ->
  stat = fs.lstatSync(p)
  if stat && stat.isDirectory()
    return on
  return off

isFile = (p) ->
  stat = fs.lstatSync(p)
  if stat && stat.isFile()
    return on
  return off

module.exports =
class MiniDocument

  isLoadedDone: off
  weexDoc: {}
  nageland: null
  constructor: ->
    @nageland = new Nageland

  isLoaded: ->
    @isLoadedDone = on;

  load: ->
    doczip = path.join atom.configDirPath, 'doc.zip'
    if isFile doczip
      @nageland.load doczip, => @isLoaded()
    else
      @resolveDocDirectory()

  resolveDocDirectory: ->
    # debug mode find doc
    if isDirectory atom.configDirPath
      docPath = path.join atom.configDirPath, 'doc'
      @ensureDir docPath

      docConfigPath = path.join docPath, 'MANIFEST.json'
      config = {}

      if fs.existsSync docConfigPath
        config = JSON.parse docConfigPath
        for key, value of config
          docFile = path.join docPath, value
          @weexDoc[key] = fs.readFileSync docFile if fs.existsSync docFile

  ensureDir: (dirPath) ->
    # 如果docs不存在，则创建
    if not fs.existsSync dirPath
      fs.mkdirSync dirPath

    # 如果存在但是不是目录就删掉重新建目录
    if not isDirectory dirPath
      fs.unlinkSync dirPath
      fs.mkdirSync dirPath

  ###
  # Document text provider
  # @param cope: such as .source.we .source.lua
  # @param name: such as suggestion list text
  # @return the selected doc
  ###
  getMiniDocumentSection: (scope, name, callback) ->
    @nageland.readHtml scope, name, callback
