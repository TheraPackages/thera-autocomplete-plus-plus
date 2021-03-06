{Disposable, CompositeDisposable} = require 'atom'
SnippetParser = require './snippet-parser'
{isString} = require('./type-helpers')
fuzzaldrinPlus = require 'fuzzaldrin-plus'
$ = window.$ = window.jQuery = require 'jquery'
hl = require("highlight").Highlight

ItemTemplate = """
  <span class="icon-container"></span>
  <span class="left-label"></span>
  <span class="word-container">
    <span class="word"></span>
  </span>
  <span class="right-label"></span>
"""

code_string = "<?php\r\n"+
                  "\techo \"Hello world!\";\r\n"+
                  "\tfor($i=0;$i<100;$i++){\r\n"+
                  "\t\techo \"$i\";\r\n"+
                  "\t}\r\n"+
                  "?>"

ListTemplate = """
  <div class='mainContext-box-main'>
    <div class="leftContext-box-left">
      <div class="suggestion-list-scroller">
        <ol class="list-group"></ol>
      </div>

    </div>
    <div class="rightContext-box-right">
      <div class="suggestDetail">
      </div>
    </div>
    <div class="suggestion-description">
      <span class="suggestion-description-content"></span>
      <a class="suggestion-description-more-link" href="#">More..</a>
    </div>
  </div>
"""
#
# ListTemplate = """
#   <div class='mainContext-box-main'>
#     <div class="leftContext-box-left">
#       <div class="suggestion-list-scroller">
#         <ol class="list-group"></ol>
#       </div>
#       <div class="suggestion-description">
#         <span class="suggestion-description-content"></span>
#         <a class="suggestion-description-more-link" href="#">More..</a>
#       </div>
#     </div>
#     <div class="rightContext-box-right">
#       <div class="suggestDetail">
#           <!-- title -->
#           <span class="span-line-block">
#           </span>
#
#           <!-- 描述 -->
#           <div class="div-explain-element">
#           </div>
#
#           <!-- 例子 -->
#           <div class="mytheme">
#             <pre class="hljs"><code class="html"></code></pre>
#           </div>
#
#           <!-- 剩余内容 -->
#           <div class="detail-text">
#           </div>
#       </div>
#     </div>
#   </div>
# """

ListTemplate_BackUp = """
  <div class='mainContext-box-main'>
    <div class="leftContext-box-left">
      <div class="suggestion-list-scroller">
        <ol class="list-group"></ol>
      </div>

    </div>
    <div class="rightContext-box-right">
      <div class="suggestDetail">
          <!-- title -->
          <span class="span-line-block">
            <span style="font-size: 14px;color: #cc554d"> &lt a &gt </span>
            <span style="font-size: 14px;color:#d1d2d7"> of Element </span>
          </span>
          <!-- 描述 -->
          <div class="div-explain-element">
            <span style="font-size: 12px;color: darkgrey"> 必须的，使用 HTML 语法描述页面结构，内容由多个标签组成，不同的标签代表不同的组件。 </span>
          </div>
          <div class="mytheme">
            <!-- 例子 -->
            <pre class="hljs"><code class="html">#{hl(code_string)}</code></pre>
          </div>
          <!-- 剩余内容 -->
          <div class = "detail-text">
            <h2 id="样式"><a href="#样式" class="headerlink" title="样式"></a>样式</h2><p><code>&lt;a&gt;</code> 支持所有通用样式。</p>
            <ul>
            <li>盒模型</li>
            <li><code>flexbox</code> 布局</li>
            <li><code>position</code></li>
            <li><code>opacity</code></li>
            <li><code>background-color</code></li>
            </ul>
            <p>查看 <a href="../common-style.html">组件通用样式</a>。</p>
          </div>
      </div>
    </div>
    <div class="suggestion-description" >
      <span class="suggestion-description-content"></span>
      <a class="suggestion-description-more-link" href="#">More..</a>
    </div>
  </div>
"""

IconTemplate = '<i class="icon"></i>'

DefaultSuggestionTypeIconHTML =
  'snippet': '<span class=\"icon-letter\">L</span>'
  'import': '<i class="icon-package"></i>'
  'require': '<i class="icon-package"></i>'
  'module': '<i class="icon-package"></i>'
  'package': '<i class="icon-package"></i>'
  'tag': '<i class="icon-code"></i>'
  'attribute': '<i class="icon-tag"></i>'

SnippetStart = 1
SnippetEnd = 2
SnippetStartAndEnd = 3

scopesByFenceName =
  'sh': 'source.shell'
  'bash': 'source.shell'
  'c': 'source.c'
  'c++': 'source.cpp'
  'cpp': 'source.cpp'
  'coffee': 'source.coffee'
  'coffeescript': 'source.coffee'
  'coffee-script': 'source.coffee'
  'cs': 'source.cs'
  'csharp': 'source.cs'
  'css': 'source.css'
  'scss': 'source.css.scss'
  'sass': 'source.sass'
  'erlang': 'source.erl'
  'go': 'source.go'
  'html': 'text.html.basic'
  'java': 'source.java'
  'js': 'source.js'
  'javascript': 'source.js'
  'json': 'source.json'
  'less': 'source.less'
  'mustache': 'text.html.mustache'
  'objc': 'source.objc'
  'objective-c': 'source.objc'
  'php': 'text.html.php'
  'py': 'source.python'
  'python': 'source.python'
  'rb': 'source.ruby'
  'ruby': 'source.ruby'
  'text': 'text.plain'
  'toml': 'source.toml'
  'xml': 'text.xml'
  'yaml': 'source.yaml'
  'yml': 'source.yaml'
  'we': 'source.we'
  'weexvue': 'source.weexvue'


scopeForFenceName = (name) ->
  scopesByFenceName[name]

convertCodeBlocksToAtomEditors = (domFragment, defaultLanguage='text') ->

  if fontFamily = atom.config.get('editor.fontFamily')

    for codeElement in domFragment.querySelectorAll('code')
      codeElement.style.fontFamily = fontFamily

  for preElement in domFragment.querySelectorAll('pre')
    codeBlock = preElement.firstElementChild ? preElement
    fenceName = codeBlock.getAttribute('class')?.replace(/^lang-/, '') ? defaultLanguage

    editorElement = document.createElement('atom-text-editor')
    editorElement.style['padding'] = "1em"
    editorElement.style['border-radius'] = "3px"
    editorElement.style['font-size'] = "0.9em"
    editorElement.setAttributeNode(document.createAttribute('gutter-hidden'))
    editorElement.removeAttribute('tabindex') # make read-only

    preElement.parentNode.insertBefore(editorElement, preElement)
    preElement.remove()

    editor = editorElement.getModel()
    # remove the default selection of a line in each editor
    editor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    editor.setText(codeBlock.textContent)
    # if grammar = atom.grammars.grammarForScopeName(scopeForFenceName(fenceName))
    if grammar = atom.grammars.grammarForScopeName(scopeForFenceName(fenceName))
      editor.setGrammar(grammar)

  domFragment

class SuggestionListElement extends HTMLElement
  maxItems: 200
  emptySnippetGroupRegex: /(\$\{\d+\:\})|(\$\{\d+\})|(\$\d+)/ig
  nodePool: null
  miniDocument: null
  selectedIndex: 0

  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @classList.add('popover-list', 'select-list', 'autocomplete-suggestion-list')
    @registerMouseHandling()
    @snippetParser = new SnippetParser
    @nodePool = []

  attachedCallback: ->
    # TODO: Fix overlay decorator to in atom to apply class attribute correctly, then move this to overlay creation point.
    @parentElement.classList.add('thera-autocomplete-plus-plus')
    @addActiveClassToEditor()
    @renderList() unless @ol
    @itemsChanged()

  detachedCallback: ->
    @activeClassDisposable?.dispose()

  initialize: (@model, miniDoc) ->
    return unless @model?
    @miniDocument = miniDoc

    @subscriptions.add @model.onDidChangeItems(@itemsChanged.bind(this))
    @subscriptions.add @model.onDidSelectNext(@moveSelectionDown.bind(this))
    @subscriptions.add @model.onDidSelectPrevious(@moveSelectionUp.bind(this))
    @subscriptions.add @model.onDidSelectPageUp(@moveSelectionPageUp.bind(this))
    @subscriptions.add @model.onDidSelectPageDown(@moveSelectionPageDown.bind(this))
    @subscriptions.add @model.onDidSelectTop(@moveSelectionToTop.bind(this))
    @subscriptions.add @model.onDidSelectBottom(@moveSelectionToBottom.bind(this))
    @subscriptions.add @model.onDidConfirmSelection(@confirmSelection.bind(this))
    @subscriptions.add @model.onDidconfirmSelectionIfNonDefault(@confirmSelectionIfNonDefault.bind(this))
    @subscriptions.add @model.onDidDispose(@dispose.bind(this))

    @subscriptions.add atom.config.observe 'thera-autocomplete-plus-plus.suggestionListFollows', (@suggestionListFollows) =>
    @subscriptions.add atom.config.observe 'thera-autocomplete-plus-plus.maxVisibleSuggestions', (@maxVisibleSuggestions) =>
    @subscriptions.add atom.config.observe 'thera-autocomplete-plus-plus.useAlternateScoring', (@useAlternateScoring) =>

    this

  # This should be unnecessary but the events we need to override
  # are handled at a level that can't be blocked by react synthetic
  # events because they are handled at the document
  registerMouseHandling: ->
    @onmousewheel = (event) -> event.stopPropagation()
    @onmousedown = (event) ->
      item = @findItem(event)
      if item?.dataset.index?
        @selectedIndex = item.dataset.index
        event.stopPropagation()

    @onmouseup = (event) ->
      item = @findItem(event)
      if item?.dataset.index?
        event.stopPropagation()
        @confirmSelection()

  findItem: (event) ->
    item = event.target
    item = item.parentNode while item.tagName isnt 'LI' and item isnt this
    item if item.tagName is 'LI'

  updateDescription: (item) ->
    item = item ? @model?.items?[@selectedIndex]
    return unless item?

    if item.description? and item.description.length > 0
      @descriptionContainer.style.display = 'inline'
      @descriptionContent.textContent = item.description
      if item.descriptionMoreURL? and item.descriptionMoreURL.length?
        @descriptionMoreLink.style.display = 'inline'
        @descriptionMoreLink.setAttribute('href', item.descriptionMoreURL)
      else
        @descriptionMoreLink.style.display = 'none'
        @descriptionMoreLink.setAttribute('href', '#')
    else
      @descriptionContainer.style.display = 'none'

  itemsChanged: ->
    if @model?.items?.length
      @render()
    else
      @returnItemsToPool(0)

  render: ->
    @nonDefaultIndex = false
    @selectedIndex = 0
    atom.views.pollAfterNextUpdate?()
    atom.views.updateDocument @renderItems.bind(this)
    atom.views.readDocument @readUIPropsFromDOM.bind(this)


  addActiveClassToEditor: ->
    editorElement = atom.views.getView(@model?.activeEditor)
    editorElement?.classList?.add 'autocomplete-active'
    @activeClassDisposable = new Disposable ->
      editorElement?.classList?.remove 'autocomplete-active'

  moveSelectionUp: ->
    unless @selectedIndex <= 0
      @setSelectedIndex(@selectedIndex - 1)
    else
      @setSelectedIndex(@visibleItems().length - 1)

  moveSelectionDown: ->
    unless @selectedIndex >= (@visibleItems().length - 1)
      @setSelectedIndex(@selectedIndex + 1)
    else
      @setSelectedIndex(0)

  moveSelectionPageUp: ->
    newIndex = Math.max(0, @selectedIndex - @maxVisibleSuggestions)
    @setSelectedIndex(newIndex) if @selectedIndex isnt newIndex

  moveSelectionPageDown: ->
    itemsLength = @visibleItems().length
    newIndex = Math.min(itemsLength - 1, @selectedIndex + @maxVisibleSuggestions)
    @setSelectedIndex(newIndex) if @selectedIndex isnt newIndex

  moveSelectionToTop: ->
    newIndex = 0
    @setSelectedIndex(newIndex) if @selectedIndex isnt newIndex

  moveSelectionToBottom: ->
    newIndex = @visibleItems().length - 1
    @setSelectedIndex(newIndex) if @selectedIndex isnt newIndex

  setSelectedIndex: (index) ->
    @nonDefaultIndex = true
    @selectedIndex = index
    atom.views.updateDocument @renderSelectedItem.bind(this)

  visibleItems: ->
    @model?.items?.slice(0, @maxItems)

  # Private: Get the currently selected item
  #
  # Returns the selected {Object}
  getSelectedItem: ->
    @model?.items?[@selectedIndex]

  # Private: Confirms the currently selected item or cancels the list view
  # if no item has been selected
  confirmSelection: ->
    return unless @model.isActive()
    item = @getSelectedItem()
    if item?
      @model.confirm(item)
    else
      @model.cancel()

  # Private: Confirms the currently selected item only if it is not the default
  # item or cancels the view if none has been selected.
  confirmSelectionIfNonDefault: (event) ->
    return unless @model.isActive()
    if @nonDefaultIndex
      @confirmSelection()
    else
      @model.cancel()
      event.abortKeyBinding()

  renderList: ->
    @innerHTML = ListTemplate
    @ol = @querySelector('.list-group')
    @scroller = @querySelector('.suggestion-list-scroller')
    @rightContext = @querySelector('.suggestDetail')

    @descriptionContainer = @querySelector('.suggestion-description')
    @descriptionContent = @querySelector('.suggestion-description-content')
    @descriptionMoreLink = @querySelector('.suggestion-description-more-link')

  resvData: (data) ->
    docContent = data
    if docContent
      @rightContext.style['display'] = ""
      @rightContext.innerHTML = docContent
      convertCodeBlocksToAtomEditors @rightContext
      # code = @querySelector '.lang-html'
      # if code
      #   console.log code.innerHTML
      #   code.innerHTML = hl code.textContent
      #
      # for key, value of docContent
      #   subContainer = @querySelector('.' + key)
      #   break unless subContainer
      #   if key is 'html' # CSON不支持 #{} ... html 用hl特别处理。。
      #     subContainer.innerHTML = hl(value)
      #   else
      #     subContainer.innerHTML = value
    else
      @rightContext.style['display'] = 'none'

  renderDocument: ->
    items = @visibleItems()

    selectedItem = items[@selectedIndex]
    scope = selectedItem.provider.selector
    name = selectedItem.text || selectedItem.displayText
    activeDoc = selectedItem.activeDoc
    if activeDoc
      @resvData(activeDoc)
    else
      @resvData("")
      @miniDocument.getMiniDocumentSection scope, name, (data) => @resvData(data)

  renderItems: ->
    @renderDocument()
    @style.width = null
    items = @visibleItems() ? []
    longestDesc = 0
    longestDescIndex = null

    for item, index in items
      @renderItem(item, index)
      descLength = @descriptionLength(item)
      if descLength > longestDesc
        longestDesc = descLength
        longestDescIndex = index
    @updateDescription(items[longestDescIndex])
    @returnItemsToPool(items.length)

  returnItemsToPool: (pivotIndex) ->
    while @ol? and li = @ol.childNodes[pivotIndex]
      li.remove()
      @nodePool.push(li)
    return

  descriptionLength: (item) ->
    count = 0
    if item.description?
      count += item.description.length
    if item.descriptionMoreURL?
      count += 6
    count

  renderSelectedItem: ->
    @selectedLi?.classList.remove('selected-plus')
    @selectedLi = @ol.childNodes[@selectedIndex]
    if @selectedLi?
      @selectedLi.classList.add('selected-plus')
      @scrollSelectedItemIntoView()
      @updateDescription()
      @renderDocument()

  # This is reading the DOM in the updateDOM cycle. If we dont, there is a flicker :/
  scrollSelectedItemIntoView: ->
    scrollTop = @scroller.scrollTop
    selectedItemTop = @selectedLi.offsetTop
    if selectedItemTop < scrollTop
      # scroll up
      return @scroller.scrollTop = selectedItemTop

    itemHeight = @uiProps.itemHeight
    scrollerHeight = @maxVisibleSuggestions * itemHeight + @uiProps.paddingHeight
    if selectedItemTop + itemHeight > scrollTop + scrollerHeight
      # scroll down
      @scroller.scrollTop = selectedItemTop - scrollerHeight + itemHeight

  readUIPropsFromDOM: ->
    wordContainer = @selectedLi?.querySelector('.word-container')

    @uiProps ?= {}
    @uiProps.width = @offsetWidth + 1
    @uiProps.marginLeft = -(wordContainer?.offsetLeft ? 0)
    @uiProps.itemHeight ?= @selectedLi.offsetHeight
    @uiProps.paddingHeight ?= (parseInt(getComputedStyle(this)['padding-top']) + parseInt(getComputedStyle(this)['padding-bottom'])) ? 0

    # Update UI during this read, so that when polling the document the latest
    # changes can be picked up.
    @updateUIForChangedProps()

  updateUIForChangedProps: ->
    #@scroller.style['max-height'] = "#{@maxVisibleSuggestions * @uiProps.itemHeight + @uiProps.paddingHeight}px"
    #@scroller.style['min-height'] = @scroller.style['max-height']
    # $(@descriptionMoreLink).height()

    #console.log parseInt(@scroller.style['max-height'])

    @rightContext.style['height'] =  "#{parseInt(@scroller.style['max-height']) + 25}px"

    #tempheight = $.parseInt(@scroller.style['max-height'],$(@descriptionMoreLink).height())

    #console.log tempheight

    @style.width = "#{@uiProps.width}px"
    if @suggestionListFollows is 'Word'
      @style['margin-left'] = "#{@uiProps.marginLeft}px"


    @updateDescription()

  # Splits the classes on spaces so as not to anger the DOM gods
  addClassToElement: (element, classNames) ->
    if classNames and classes = classNames.split(' ')
      for className in classes
        className = className.trim()
        element.classList.add(className) if className
    return

  renderItem: ({iconHTML, type, snippet, text, displayText, className, replacementPrefix, leftLabel, leftLabelHTML, rightLabel, rightLabelHTML}, index) ->
    li = @ol.childNodes[index]
    unless li
      if @nodePool.length > 0
        li = @nodePool.pop()
      else
        li = document.createElement('li')
        li.innerHTML = ItemTemplate
      li.dataset.index = index
      @ol.appendChild(li)

    li.className = ''
    li.classList.add('selected-plus') if index is @selectedIndex
    @addClassToElement(li, className) if className
    @selectedLi = li if index is @selectedIndex

    typeIconContainer = li.querySelector('.icon-container')
    typeIconContainer.innerHTML = ''

    sanitizedType = escapeHtml(if isString(type) then type else '')
    sanitizedIconHTML = if isString(iconHTML) then iconHTML else undefined
    defaultLetterIconHTML = if sanitizedType then "<span class=\"icon-letter\">#{sanitizedType[0]}</span>" else ''
    defaultIconHTML = DefaultSuggestionTypeIconHTML[sanitizedType] ? defaultLetterIconHTML

    if (sanitizedIconHTML or defaultIconHTML) # and iconHTML isnt false
      typeIconContainer.innerHTML = IconTemplate
      typeIcon = typeIconContainer.childNodes[0]
      typeIcon.innerHTML = sanitizedIconHTML ? defaultIconHTML
      @addClassToElement(typeIcon, type) if type

    wordSpan = li.querySelector('.word')
    wordSpan.innerHTML = @getDisplayHTML(text, snippet, displayText, replacementPrefix)

    leftLabelSpan = li.querySelector('.left-label')
    if leftLabelHTML?
      leftLabelSpan.innerHTML = leftLabelHTML
    else if leftLabel?
      leftLabelSpan.textContent = leftLabel
    else
      leftLabelSpan.textContent = ''

    rightLabelSpan = li.querySelector('.right-label')
    if rightLabelHTML?
      rightLabelSpan.innerHTML = rightLabelHTML
    else if rightLabel?
      rightLabelSpan.textContent = rightLabel
    else
      rightLabelSpan.textContent = ''

  getDisplayHTML: (text, snippet, displayText, replacementPrefix) ->
    replacementText = text
    if typeof displayText is 'string'
      replacementText = displayText
    else if typeof snippet is 'string'
      replacementText = @removeEmptySnippets(snippet)
      snippets = @snippetParser.findSnippets(replacementText)
      replacementText = @removeSnippetsFromText(snippets, replacementText)
      snippetIndices = @findSnippetIndices(snippets)
    characterMatchIndices = @findCharacterMatchIndices(replacementText, replacementPrefix)

    displayHTML = ''
    for character, index in replacementText
      if snippetIndices?[index] in [SnippetStart, SnippetStartAndEnd]
        displayHTML += '<span class="snippet-completion">'
      if characterMatchIndices?[index]
        displayHTML += '<span class="character-match">' + escapeHtml(replacementText[index]) + '</span>'
      else
        displayHTML += escapeHtml(replacementText[index])
      if snippetIndices?[index] in [SnippetEnd, SnippetStartAndEnd]
        displayHTML += '</span>'
    displayHTML

  removeEmptySnippets: (text) ->
    return text unless text?.length and text.indexOf('$') isnt -1 # No snippets
    text.replace(@emptySnippetGroupRegex, '') # Remove all occurrences of $0 or ${0} or ${0:}

  # Will convert 'abc(${1:d}, ${2:e})f' => 'abc(d, e)f'
  #
  # * `snippets` {Array} from `SnippetParser.findSnippets`
  # * `text` {String} to remove snippets from
  #
  # Returns {String}
  removeSnippetsFromText: (snippets, text) ->
    return text unless text.length and snippets?.length
    index = 0
    result = ''
    for {snippetStart, snippetEnd, body} in snippets
      result += text.slice(index, snippetStart) + body
      index = snippetEnd + 1
    result += text.slice(index, text.length) if index isnt text.length
    result

  # Computes the indices of snippets in the resulting string from
  # `removeSnippetsFromText`.
  #
  # * `snippets` {Array} from `SnippetParser.findSnippets`
  #
  # e.g. A replacement of 'abc(${1:d})e' is replaced to 'abc(d)e' will result in
  #
  # `{4: SnippetStartAndEnd}`
  #
  # Returns {Object} of {index: SnippetStart|End|StartAndEnd}
  findSnippetIndices: (snippets) ->
    return unless snippets?
    indices = {}
    offsetAccumulator = 0
    for {snippetStart, snippetEnd, body} in snippets
      bodyLength = body.length
      snippetLength = snippetEnd - snippetStart + 1
      startIndex = snippetStart - offsetAccumulator
      endIndex = startIndex + bodyLength - 1
      offsetAccumulator += snippetLength - bodyLength

      if startIndex is endIndex
        indices[startIndex] = SnippetStartAndEnd
      else
        indices[startIndex] = SnippetStart
        indices[endIndex] = SnippetEnd
    indices

  # Finds the indices of the chars in text that are matched by replacementPrefix
  #
  # e.g. text = 'abcde', replacementPrefix = 'acd' Will result in
  #
  # {0: true, 2: true, 3: true}
  #
  # Returns an {Object}
  findCharacterMatchIndices: (text, replacementPrefix) ->
    return unless text?.length and replacementPrefix?.length
    matches = {}
    if @useAlternateScoring
      matchIndices = fuzzaldrinPlus.match(text, replacementPrefix)
      matches[i] = true for i in matchIndices
    else
      wordIndex = 0
      for ch, i in replacementPrefix
        while wordIndex < text.length and text[wordIndex].toLowerCase() isnt ch.toLowerCase()
          wordIndex += 1
        break if wordIndex >= text.length
        matches[wordIndex] = true
        wordIndex += 1
    matches

  dispose: ->
    @subscriptions.dispose()
    @parentNode?.removeChild(this)

# https://github.com/component/escape-html/blob/master/index.js
escapeHtml = (html) ->
  String(html)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

module.exports = SuggestionListElement = document.registerElement('autocomplete-suggestion-list', {prototype: SuggestionListElement.prototype})
