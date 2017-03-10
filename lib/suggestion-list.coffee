{Emitter, CompositeDisposable} = require 'atom'
{UnicodeLetters} = require './unicode-helpers'

module.exports =
class SuggestionList
  wordPrefixRegex: null

  constructor: ->
    @activeEditor = null
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor.autocomplete-active',
      'thera-autocomplete-plus-plus:confirm': @confirmSelection,
      'thera-autocomplete-plus-plus:confirmIfNonDefault': @confirmSelectionIfNonDefault,
      'thera-autocomplete-plus-plus:cancel': @cancel
    @subscriptions.add(atom.config.observe('thera-autocomplete-plus-plus.enableExtendedUnicodeSupport', (enableExtendedUnicodeSupport) =>
      if enableExtendedUnicodeSupport
        @wordPrefixRegex = new RegExp("^[#{UnicodeLetters}\\d_-]")
      else
        @wordPrefixRegex = /^[\w-]/
    ))

  addBindings: (editor) ->
    @bindings?.dispose()
    @bindings = new CompositeDisposable

    completionKey = atom.config.get('thera-autocomplete-plus-plus.confirmCompletion') or ''

    keys = {}
    keys['tab'] = 'thera-autocomplete-plus-plus:confirm' if completionKey.indexOf('tab') > -1
    if completionKey.indexOf('enter') > -1
      if completionKey.indexOf('always') > -1
        keys['enter'] = 'thera-autocomplete-plus-plus:confirmIfNonDefault'
      else
        keys['enter'] = 'thera-autocomplete-plus-plus:confirm'

    @bindings.add atom.keymaps.add(
      'atom-text-editor.autocomplete-active',
      {'atom-text-editor.autocomplete-active': keys})

    useCoreMovementCommands = atom.config.get('thera-autocomplete-plus-plus.useCoreMovementCommands')
    commandNamespace = if useCoreMovementCommands then 'core' else 'thera-autocomplete-plus-plus'

    commands = {}
    commands["#{commandNamespace}:move-up"] = (event) =>
      if @isActive() and @items?.length > 1
        @selectPrevious()
        event.stopImmediatePropagation()
    commands["#{commandNamespace}:move-down"] = (event) =>
      if @isActive() and @items?.length > 1
        @selectNext()
        event.stopImmediatePropagation()
    commands["#{commandNamespace}:page-up"] = (event) =>
      if @isActive() and @items?.length > 1
        @selectPageUp()
        event.stopImmediatePropagation()
    commands["#{commandNamespace}:page-down"] = (event) =>
      if @isActive() and @items?.length > 1
        @selectPageDown()
        event.stopImmediatePropagation()
    commands["#{commandNamespace}:move-to-top"] = (event) =>
      if @isActive() and @items?.length > 1
        @selectTop()
        event.stopImmediatePropagation()
    commands["#{commandNamespace}:move-to-bottom"] = (event) =>
      if @isActive() and @items?.length > 1
        @selectBottom()
        event.stopImmediatePropagation()

    @bindings.add atom.commands.add(
      atom.views.getView(editor), commands)

    @bindings.add(
      atom.config.onDidChange 'thera-autocomplete-plus-plus.useCoreMovementCommands', =>
        @addBindings(editor))

  ###
  Section: Event Triggers
  ###

  cancel: =>
    @emitter.emit('did-cancel')

  confirm: (match) =>
    @emitter.emit('did-confirm', match)

  confirmSelection: =>
    @emitter.emit('did-confirm-selection')

  confirmSelectionIfNonDefault: (event) =>
    @emitter.emit('did-confirm-selection-if-non-default', event)

  selectNext: ->
    @emitter.emit('did-select-next')

  selectPrevious: ->
    @emitter.emit('did-select-previous')

  selectPageUp: ->
    @emitter.emit('did-select-page-up')

  selectPageDown: ->
    @emitter.emit('did-select-page-down')

  selectTop: ->
    @emitter.emit('did-select-top')

  selectBottom: ->
    @emitter.emit('did-select-bottom')

  ###
  Section: Events
  ###

  onDidConfirmSelection: (fn) ->
    @emitter.on('did-confirm-selection', fn)

  onDidconfirmSelectionIfNonDefault: (fn) ->
    @emitter.on('did-confirm-selection-if-non-default', fn)

  onDidConfirm: (fn) ->
    @emitter.on('did-confirm', fn)

  onDidSelectNext: (fn) ->
    @emitter.on('did-select-next', fn)

  onDidSelectPrevious: (fn) ->
    @emitter.on('did-select-previous', fn)

  onDidSelectPageUp: (fn) ->
    @emitter.on('did-select-page-up', fn)

  onDidSelectPageDown: (fn) ->
    @emitter.on('did-select-page-down', fn)

  onDidSelectTop: (fn) ->
    @emitter.on('did-select-top', fn)

  onDidSelectBottom: (fn) ->
    @emitter.on('did-select-bottom', fn)

  onDidCancel: (fn) ->
    @emitter.on('did-cancel', fn)

  onDidDispose: (fn) ->
    @emitter.on('did-dispose', fn)

  onDidChangeItems: (fn) ->
    @emitter.on('did-change-items', fn)

  isActive: ->
    @activeEditor?

  show: (editor, options) =>
    if atom.config.get('thera-autocomplete-plus-plus.suggestionListFollows') is 'Cursor'
      @showAtCursorPosition(editor, options)
    else
      prefix = options.prefix
      followRawPrefix = false
      for item in @items
        if item.replacementPrefix?
          prefix = item.replacementPrefix.trim()
          followRawPrefix = true
          break
      @showAtBeginningOfPrefix(editor, prefix, followRawPrefix)

  showAtBeginningOfPrefix: (editor, prefix, followRawPrefix=false) =>
    return unless editor?

    bufferPosition = editor.getCursorBufferPosition()
    bufferPosition = bufferPosition.translate([0, -prefix.length]) if followRawPrefix or @wordPrefixRegex.test(prefix)

    if @activeEditor is editor
      unless bufferPosition.isEqual(@displayBufferPosition)
        @displayBufferPosition = bufferPosition
        @suggestionMarker?.setBufferRange([bufferPosition, bufferPosition])
    else
      @destroyOverlay()
      @activeEditor = editor
      @displayBufferPosition = bufferPosition
      marker = @suggestionMarker = editor.markBufferRange([bufferPosition, bufferPosition])
      @overlayDecoration = editor.decorateMarker(marker, {type: 'overlay', item: this, position: 'tail'})
      @addBindings(editor)

  showAtCursorPosition: (editor) =>
    return if @activeEditor is editor or not editor?
    @destroyOverlay()

    if marker = editor.getLastCursor()?.getMarker()
      @activeEditor = editor
      @overlayDecoration = editor.decorateMarker(marker, {type: 'overlay', item: this})
      @addBindings(editor)

  hide: =>
    return if @activeEditor is null
    @destroyOverlay()
    @bindings?.dispose()
    @activeEditor = null

  destroyOverlay: =>
    if @suggestionMarker?
      @suggestionMarker.destroy()
    else
      @overlayDecoration?.destroy()
    @suggestionMarker = undefined
    @overlayDecoration = undefined

  changeItems: (@items) ->
    @emitter.emit('did-change-items', @items)

  # Public: Clean up, stop listening to events
  dispose: ->
    @subscriptions.dispose()
    @bindings?.dispose()
    @emitter.emit('did-dispose')
    @emitter.dispose()
