root = exports ? this
type = (obj) ->
  if obj == undefined or obj == null
    return String obj
  classToType = {
    '[object Boolean]': 'boolean',
    '[object Number]': 'number',
    '[object String]': 'string',
    '[object Function]': 'function',
    '[object Array]': 'array',
    '[object Date]': 'date',
    '[object RegExp]': 'regexp',
    '[object Object]': 'object'
  }
  return classToType[Object.prototype.toString.call(obj)]

# Help with the placement of nodes
RadialPlacement = () ->
  # stores the key -> location values
  values = d3.map()
  # how much to separate each location by
  increment = 20
  # how large to make the layout
  radius = 200
  # where the center of the layout should be
  center = {"x":0, "y":0}
  # what angle to start at
  start = -120
  current = start

  # Given a center point, angle, and radius length,
  # return a radial position for that angle
  radialLocation = (center, angle, radius) ->
    x = (center.x + radius * Math.cos(angle * Math.PI / 180))
    y = (center.y + radius * Math.sin(angle * Math.PI / 180))
    {"x":x,"y":y}

  # Main entry point for RadialPlacement
  # Returns location for a particular key,
  # creating a new location if necessary.
  placement = (key) ->
    value = values.get(key)
    if !values.has(key)
      value = place(key)
    value

  # Gets a new location for input key
  place = (key) ->
    value = radialLocation(center, current, radius)
    values.set(key,value)
    current += increment
    value

  placeCenter = (key) ->
    value = radialLocation(center, 0, 0) 
    values.set(key, value)
    value

  # Given a set of keys, perform some 
  # magic to create a two ringed radial layout.
  # Expects radius, increment, and center to be set.
  # If there are a small number of keys, just make
  # one circle.
  setKeys = (keys) ->
    # start with an empty values
    # values = d3.map()
    # set locations for keys
    keys.forEach (k) -> placeCenter(k)
  
  #place nodes in radial layout
  setRadialKeys = (keys) ->
    # start with an empty values
    #values = d3.map()
    # modify increment
    # so that they all fit in one circle
    if(keys.length > 0)
      increment = 360 / keys.length
    # set locations for circle
    keys.forEach (k) -> place(k)
  
  placement.keys = (_) ->
    if !arguments.length
      return d3.keys(values)
    setKeys(_)
    placement

  placement.radialKeys = (_) ->
    if !arguments.length
      return d3.keys(values)
    setRadialKeys(_)
    placement

  placement.center = (_) ->
    if !arguments.length
      return center
    center = _
    placement

  placement.radius = (_) ->
    if !arguments.length
      return radius
    radius = _
    placement

  placement.start = (_) ->
    if !arguments.length
      return start
    start = _
    current = start
    placement

  placement.increment = (_) ->
    if !arguments.length
      return increment
    increment = _
    placement

  return placement

validNumber = (num) ->
  return num? && !isNaN(num)  

Network = ({layout, movement, filter, sort, chargeDivider, linkDistanceMultiplier, linkStrengthValue, radiusMultiplier, radialLayoutRadius} = {}) ->
  # variables we want to access
  # in multiple places of Network
  width = 960
  height = 800
  # allData will store the unfiltered data
  allData = []
  curLinksData = []
  curNodesData = []
  linkedByIndex = {}
  # these will hold the svg groups for
  # accessing the nodes and links display
  nodesG = null
  linksG = null
  # these will point to the circles and lines
  # of the nodes and links
  node = null
  link = null
  # variables to refect the current settings
  # of the visualization
  layout ?= "force"
  filter ?= "all"
  sort ?= "none"
  movement ?= "dynamic"
  if !validNumber(chargeDivider)
    chargeDivider = 2
  if !validNumber(linkDistanceMultiplier)
    linkDistanceMultiplier = 1
  if !validNumber(linkStrengthValue)
    linkStrengthValue = 1
  # radius multiplier used to enlarge/shrink radius of node to display
  if !validNumber(radiusMultiplier)
    radiusMultiplier = 1
  # radius used in radial layout
  if !validNumber(radialLayoutRadius)
    radialLayoutRadius = 300
  console.log(layout, filter, sort, movement, chargeDivider, linkDistanceMultiplier, linkStrengthValue, radiusMultiplier, radialLayoutRadius)
  # groupCenters will store our radial layout for
  # the group by artist layout.
  groupCenters = null

  # our force directed layout
  force = d3.layout.force()
  # color function used to color nodes
  nodeColors = d3.scale.category20()
  # tooltip used to display details
  tooltip = Tooltip("vis-tooltip", 230)

  
  # charge used in artist layout
  charge = (node) -> -Math.pow(node.radius, 2.0)/chargeDivider

  legendVisible = false
  legendDisabled = true
  
  # Starting point for network visualization
  # Initializes visualization and starts force layout
  network = (selection, data) ->
    # format our data
    allData = setupData(data)
    # create our svg and groups
    vis = d3.select(selection).append("svg")
      .attr("width", width)
      .attr("height", height)
    linksG = vis.append("g").attr("id", "links")
    nodesG = vis.append("g").attr("id", "nodes")

    # setup the size of the force environment
    force.size([width, height])

    setLayout(layout)
    setFilter(filter)

    # perform rendering and start force layout
    update()
    updateLegend()

  removeLegend = () ->
    svg = d3.select("svg")
    svg.selectAll(".legend").remove()

  updateLegend = () ->
    if legendDisabled
      return
    svg = d3.select("svg")
    svg.selectAll(".legend").remove()
    legend = svg.append("g")
      .attr("class", "legend")
      .attr("transform", "translate(50, 30)")
      .attr("data-style-padding",10)
      .style("font-size","20px")
      .call(d3.legend)
    setLegendVisibility(legendVisible)

  setLegendVisibility = (visible) ->
    svg = d3.select("svg")
    svg.selectAll(".legend").style("visibility", if visible then "visible" else "hidden")
    legendVisible = visible
	
  # The update() function performs the bulk of the
  # work to setup our visualization based on the
  # current layout/sort/filter.
  #
  # update() is called everytime a parameter changes
  # and the network needs to be reset.
  update = () ->
    # filter data to show based on current filter settings.
    curNodesData = filterNodes(allData.nodes)
    curLinksData = filterLinks(allData.links, curNodesData)
    console.log(layout)
    # sort nodes based on current sort and update centers for
    # radial layout
    if layout == "radial"
      registerNodes = registers(curNodesData)
      registerLinks = filterAdjacentLinks(curLinksData, registerNodes)
      comboNodes = combinationals(curNodesData)
      registerKeys = sortedRegisters(registerNodes, registerLinks, comboNodes)
      comboKeys = comboNodes.map (n) -> n.id
      updateCenters(registerKeys, comboKeys)

    # reset nodes in force layout
    force.nodes(curNodesData)
    
    # reset links
    force.links(curLinksData)
    # always show links in force layout
    if layout == "radial"
      moveToRadialLayout()

    #if movement == "dynamic"
      # enter / exit for nodes
    #  if layout == "force" || layout == "radial"
    updateNodes()
    updateLinks()

    # start me up!
    force.start()

    if movement == "static"
      #updateNodes()
      #updateLinks()
      while force.alpha() > 0
        force.tick()
      force.stop()
      

  # Public function to switch between layouts
  network.toggleLayout = (newLayout) ->
    force.stop()
    setLayout(newLayout)
    update()

  # Public function to switch between movements
  network.toggleMovement = (newMovement) ->
    force.stop()
    setMovement(newMovement)
    update()

  # Public function to switch between filter options
  network.toggleFilter = (newFilter) ->
    force.stop()
    setFilter(newFilter)
    update()

  # Public function to switch between sort options
  network.toggleSort = (newSort) ->
    force.stop()
    setSort(newSort)
    update()

  network.setCharge = (newCharge) ->
    force.stop()
    setCharge(newCharge)
    update()

  network.setLinkDistance = (newLinkDistanceMultiplier) ->
    force.stop()
    setLinkDistance(newLinkDistanceMultiplier)
    update()

  network.setLinkStrength = (newLinkStrength) ->
    force.stop()
    setLinkStrength(newLinkStrength)
    update()

  network.setRadialLayoutRadius = (newRadius) ->
    force.stop()
    setRadialLayoutRadius(newRadius)
    update()

  network.setRadiusMultiplier = (newRadiusMultiplier) ->
    force.stop()
    setRadiusMultiplier(newRadiusMultiplier)
    update()

  # Public function to update highlighted nodes
  # from search
  network.updateSearch = (searchTerm) ->
    searchRegEx = new RegExp(searchTerm.toLowerCase())
    node.each (d) ->
      element = d3.select(this)
      match = d.id.toLowerCase().search(searchRegEx)
      if searchTerm.length > 0 and match >= 0
        element.style("fill", "#F38630")
          .style("stroke-width", 2.0)
          .style("stroke", "#555")
        d.searched = true
      else
        d.searched = false
        element.style("fill", (d) -> nodeColors(d.shape))
          .style("stroke-width", 1.0)

  network.updateData = (newData) ->
    allData = setupData(newData)
    link.remove()
    node.remove()
    update()
    updateLegend()

  network.updateLegend = () ->
    updateLegend()

  network.removeLegend = () ->
    removeLegend()

  network.setLegendVisibility = (visible) ->
    setLegendVisibility(visible)

  stripQuotes = (text) ->
    strippedString = text
    if text.charAt(0) == '"' && text.charAt(text.length-1) == '"'
      strippedString = text.substr 1, text.length-2
    return strippedString
  # called once to clean up raw data and switch links to
  # point to node instances
  # Returns modified data
  setupData = (data) ->
    data.nodes.forEach (n) ->
      if n.size? && type(n.size) == "string"
        n.size = stripQuotes(n.size)
      if n.delay? && type(n.delay) == "string"
        n.delay = stripQuotes(n.delay)
      if n.info? && type(n.info) == "string"
        n.info = stripQuotes(n.info)
      if n.type? && type(n.type) == "string"
        n.type = stripQuotes(n.type)
    console.log("number of nodes:",data.nodes.length)
    # initialize circle radius scale
    #registerSizeMin = d3.min(registers(data.nodes), (d) -> if d.width? then parseFloat(d.width) else Number.MAX_SAFE_INTEGER)
    #registerSizeMax = d3.max(registers(data.nodes), (d) -> if d.width? then parseFloat(d.width) else Number.MIN_SAFE_INTEGER)
    #registerSizeAverage = (sizeMax - sizeMin) / 2 + sizeMin
    registerSizeExtent = d3.extent(registers(data.nodes), (d) -> if d.size? then parseInt(d.size, 10) else 0)#[sizeRegisterMin, sizeRegisterMax]
    registerCircleRadius = d3.scale.linear().range([1, 10]).domain(registerSizeExtent)
    
    registerSizeMin = registerSizeExtent[0]

    logicSizeExtent = d3.extent(combinationals(data.nodes), (d) -> if d.delay? then parseInt(d.delay, 10) else 0)#[sizeRegisterMin, sizeRegisterMax]
    logicCircleRadius = d3.scale.linear().range([1,20]).domain(logicSizeExtent)

    logicSizeMin = logicSizeExtent[0]   
   
    data.nodes.forEach (n) ->
      # set initial x/y to values within the width/height
      # of the visualization
      n.x = randomnumber = Math.floor(Math.random()*width)
      n.y = randomnumber = Math.floor(Math.random()*height)
      # add radius to the node so we can use it later
      if isRegister(n)
        size = if n.size? then parseInt(n.size, 10) else registerSizeMin
        n.radius = registerCircleRadius(size)
      else
        size = if n.delay? then parseInt(n.delay, 10) else logicSizeMin
        n.radius = logicCircleRadius(size)
    
    # id's -> node objects
    nodesMap = mapNodes(data.nodes)

    #linkExtent = d3.extent(data.links, (d) -> d.delay)
    delayMin = d3.min(data.links, (d) -> if d.weight? then parseInt(d.weight, 10) else 10)
    delayMax = d3.max(data.links, (d) -> if d.weight? then parseInt(d.weight, 10) else 10)
    delayAverage = (delayMax - delayMin) / 2 + delayMin
    delayExtent = [delayMin, delayMax]
    linkDistance = d3.scale.linear().range([10, 50]).domain(delayExtent)

    # switch links to point to node objects instead of id's
    data.links.forEach (l) ->
      key = if type(l.source) == 'number' then data.nodes[l.source].id else l.source
      l.source =  nodesMap.get(key)
      key = if type(l.target) == 'number' then data.nodes[l.target].id else l.target
      l.target = nodesMap.get(key)
      weight = if l.weight? then l.weight else 5
      l.linkDistance = linkDistance.invert(weight)
      # linkedByIndex is used for link sorting
      linkedByIndex["#{l.source.id},#{l.target.id}"] = 1
      data.nodes.forEach (n) ->
        if l.source == n || l.target == n
          if !n.links? then n.links = []
          n.links.push (l)
    data

  # Helper function to map node id's to node objects.
  # Returns d3.map of ids -> nodes
  mapNodes = (nodes) ->
    nodesMap = d3.map()
    nodes.forEach (n) ->
      nodesMap.set(n.id, n)
    nodesMap

  # Helper function that returns an associative array
  # with counts of unique attr in nodes
  # attr is value stored in node, like 'artist'
  nodeCounts = (nodes, attr) ->
    counts = {}
    nodes.forEach (d) ->
      counts[d[attr]] ?= 0
      counts[d[attr]] += 1
    counts

  # Given two nodes a and b, returns true if
  # there is a link between them.
  # Uses linkedByIndex initialized in setupData
  neighboring = (a, b) ->
    linkedByIndex[a.id + "," + b.id] or
      linkedByIndex[b.id + "," + a.id]

  # Removes nodes from input array
  # based on current filter setting.
  # Returns array of nodes
  filterNodes = (allNodes) ->
    filteredNodes = allNodes
    if filter == "popular" or filter == "obscure"
      playcounts = allNodes.map((d) -> d.playcount).sort(d3.ascending)
      cutoff = d3.quantile(playcounts, 0.5)
      filteredNodes = allNodes.filter (n) ->
        if filter == "popular"
          n.playcount > cutoff
        else if filter == "obscure"
          n.playcount <= cutoff

    filteredNodes

  # Returns array of artists sorted based on
  # current sorting method.
  sortedArtists = (nodes,links) ->
    artists = []
    if sort == "links"
      counts = {}
      links.forEach (l) ->
        counts[l.source.artist] ?= 0
        counts[l.source.artist] += 1
        counts[l.target.artist] ?= 0
        counts[l.target.artist] += 1
      # add any missing artists that dont have any links
      nodes.forEach (n) ->
        counts[n.artist] ?= 0

      # sort based on counts
      artists = d3.entries(counts).sort (a,b) ->
        b.value - a.value
      # get just names
      artists = artists.map (v) -> v.key
    else
      # sort artists by song count
      counts = nodeCounts(nodes, "artist")
      artists = d3.entries(counts).sort (a,b) ->
        b.value - a.value
      artists = artists.map (v) -> v.key

    artists

  #helper methods for sorting registers
  #links must be connected to at least one register
  #removes links that connect node to register
  findRegistersConnectedToNode = (node, links) ->
    registersFound = []
    links.forEach (l, index) ->
      regToAdd = null
      if l.source == node && isRegister(l.target)
        regToAdd = l.target
      else if l.target == node && isRegister(l.source)
        regToAdd = l.source
      if regToAdd != null
        registersFound.push(regToAdd)
        links.splice(index, 1)
    registersFound

  updateNodesConnectedToRegisters = (counts, registers, nodes, links) ->
    links.forEach (l, index) ->
      if l.source in registers && l.target in nodes
        counts[l.target.id] ?= 0
        counts[l.target.id] += 1
        links.splice(index, 1)
      else if l.target in registers && l.source in nodes
        counts[l.source.id] ?= 0
        counts[l.source.id] += 1
        links.splice(index, 1)

  breadthFirstStep = (node, callback) ->
    nextNodes = []
    node.visited = true
    callback? node
    node.links.forEach (l) ->
      otherNode = if l.source == node then l.target else l.source
      if !otherNode.visited
        nextNodes.push(otherNode)
    nextNodes

  breadthFirst = (nodes, otherNodes, callback) ->
    copyOfNodes = nodes.slice()
    # initialize nodes for breadth first visit 
    otherNodes.forEach (n) ->
      n.visited = false
    copyOfNodes.forEach (n) ->
      n.visited = false
    nodesAtLevel = []
    numSteps = 0
    origin = ""
    while copyOfNodes.length > 0
      if nodesAtLevel.length == 0
        nodesAtLevel.push(copyOfNodes[0])
        copyOfNodes.splice(0, 1)
        numSteps = 0
        origin = nodesAtLevel[0]
      temp = new Set()
      
      nodesAtLevel.forEach (n) ->
        #if isRegister(n)
        #  console.log(numSteps, "steps from", origin.info, "to", n.info)
        nextNodes = breadthFirstStep(n, callback)
        temp.add(nextNode) for nextNode in nextNodes
      numSteps += 1
      nodesAtLevel = if temp.size > 0 then Array.from(temp) else []
      #copyOfNodesIds = copyOfNodes.map (n) -> n.id
      #nodesAtLevelIds = nodesAtLevel.map (n) -> n.id

  depthFirst = (nodes, otherNodes, callback) ->
    copyOfNodes = nodes.slice()
	# initialize nodes for depth first visit 
    otherNodes.forEach (n) ->
      n.visited = false
    copyOfNodes.forEach (n) ->
      n.visited = false
    while copyOfNodes.length > 0
      nextNodes = breadthFirstStep(copyOfNodes[0], callback)
      copyOfNodes.splice(0, 1)
      # append next nodes to front to visit first
      if n not in copyOfNodes then copyOfNodes.unshift n for n in nextNodes
      #nextNodes.forEach (n) ->
      #  if n not in copyOfNodes
      #    copyOfNodes.unshift(n)

  sortedRegisters = (nodes, links, otherNodes) ->
    regs = []
    if sort == "links"
      counts = {}
      links.forEach (l) ->
        if l.source in nodes
          counts[l.source.id] ?= 0
          counts[l.source.id] += 1
        if l.target in nodes
          counts[l.target.id] ?= 0
          counts[l.target.id] += 1
      # add any missing artists that dont have any links
      nodes.forEach (n) ->
        counts[n.id] ?= 0
      #sort based on counts
      regs = d3.entries(counts).sort (a,b) ->
        b.value - a.value
      regs = regs.map (v) -> v.key
    else if sort == "size"
      # sort registers by size
      sortedNodes = nodes.sort (a,b) ->
        b.radius - a.radius
      regs = sortedNodes.map (n) -> n.id
    else if sort == "children"
      visitedNodes = new Set()
      nodesLeft = otherNodes.slice()
      curNode = nodesLeft[0]
      counts = {} # key: node id ; value: number of connections from regs to nodesLeft
      regs = new Set()
      localLinks = links.slice()
      while visitedNodes.size < otherNodes.length 
        newRegisters = findRegistersConnectedToNode(curNode, localLinks)
        #add unique registers to regs array
        newRegisters.forEach (n) ->
          regs.add(n)
        #remove node from nodesleft
        index = nodesLeft.indexOf(curNode)
        if index > -1
          visitedNodes.add(curNode)
          nodesLeft.splice(index, 1)
        if newRegisters > 0
          updateNodesConnectedToRegisters(counts, newRegisters, nodesLeft, localLinks)
          newNode = d3.max(nodesLeft, (n) -> if counts[n.id]? then counts[n.id] else 0)
          curNode = newNode
        else 
          curNode = nodesLeft[0]
      nodes.forEach (n) ->
        regs.add(n)
      regs = Array.from(regs)
      regs = regs.map (v) -> v.id
    else if sort == "random"
      sortedNodes = nodes.sort (a,b) ->
        0.5 - Math.random()
      regs = sortedNodes.map (n) -> n.id
    else if sort == "breadthFirst"
      breadthFirst(nodes, otherNodes, (n) ->
        if n.id not in regs && isRegister(n)
          regs.push(n.id)
      )
    else if sort == "depthFirst"
      depthFirst(nodes, otherNodes, (n) ->
        if n.id not in regs && isRegister(n)
          regs.push(n.id)
      )
    else if sort == "alpha"
      # sort nodes alphabetically
      sortedNodes = nodes.sort (a,b) ->
        aString = a.id.toLowerCase()
        bString = b.id.toLowerCase()
        if aString < bString 
          return -1 
        else if aString > bString
          return 1
        else
          return 0
      regs = sortedNodes.map (n) -> n.id
    else
      regs = nodes
    regs
  
  registers = (nodes) ->
    regs = nodes.filter (d) -> isRegister(d)
    regs

  combinationals = (nodes) ->
    combs = nodes.filter (d) -> !isRegister(d)
    combs

  isRegister = (node) ->
    return node.type == "Register" || node.type == "Constant" || node.type == "PipeLine"

  updateCenters = (registerKeys, combinationalKeys) ->
    if layout == "radial"
      groupCenters = RadialPlacement().center({"x":width/2, "y":height / 2})
        .radius(radialLayoutRadius).keys(combinationalKeys).radialKeys(registerKeys)

  # Removes links from allLinks whose
  # source or target is not present in curNodes
  # Returns array of links
  filterLinks = (allLinks, curNodes) ->
    curNodes = mapNodes(curNodes)
    allLinks.filter (l) ->
      curNodes.get(l.source.id) and curNodes.get(l.target.id)

  filterAdjacentLinks = (allLinks, curNodes) ->
    curNodes = mapNodes(curNodes)
    allLinks.filter (l) ->
      isSource = curNodes.get(l.source.id)
      isTarget = curNodes.get(l.target.id)
      isSource ? !isTarget : isTarget #XOR
  # enter/exit display for nodes
  updateNodes = () ->
    node = nodesG.selectAll("circle.node")
      .data(curNodesData, (d) -> d.id).attr("r", (d) -> d.radius * radiusMultiplier)
    node.enter().append("circle")
      .attr("class", "node")
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)
      .attr("r", (d) -> d.radius * radiusMultiplier)
      .attr("data-legend", (d) -> d.type)
      .style("fill", (d) -> nodeColors(d.type))
      .style("stroke", (d) -> strokeFor(d))
      .style("stroke-width", 1.0)

    node.on("mouseover", showDetails)
      .on("mouseout", hideDetails)

    node.exit().remove()

  # enter/exit display for links
  updateLinks = () ->
    link = linksG.selectAll("line.link")
      .data(curLinksData, (d) -> "#{d.source.id}_#{d.target.id}")
    link.enter().append("line")
      .attr("class", "link")
      .attr("stroke", "gray")
      .attr("stroke-opacity", 0.8)
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)
    link.exit().remove()

  # switches force to new layout parameters
  setLayout = (newLayout) ->
    layout = newLayout
    if layout == "force"
      force.on("tick", forceTick)
        .charge(charge)#-200
        .linkStrength(linkStrengthValue).linkDistance((l) -> l.linkDistance * linkDistanceMultiplier)
    else if layout == "radial"
      force.on("tick", radialTick)
        .charge(charge)
        .linkStrength(linkStrengthValue).linkDistance((l) -> l.linkDistance * linkDistanceMultiplier)

  # switches movement option to new movement
  setMovement = (newMovement) ->
    movement = newMovement

  # switches filter option to new filter
  setFilter = (newFilter) ->
    filter = newFilter

  # switches sort option to new sort
  setSort = (newSort) ->
    sort = newSort

  setCharge = (newCharge) ->
    chargeDivider = newCharge
    charge = (node) -> -Math.pow(node.radius, 2.0)/chargeDivider
    force.charge(charge)

  setLinkDistance = (newLinkDistanceMultiplier) ->
    linkDistanceMultiplier = newLinkDistanceMultiplier 
    force.linkDistance((l) -> l.linkDistance * linkDistanceMultiplier)

  setLinkStrength = (newLinkStrength) ->
    linkStrengthValue = newLinkStrength
    force.linkStrength(linkStrengthValue)

  setRadialLayoutRadius = (newRadialLayoutRadius) ->
    radialLayoutRadius = newRadialLayoutRadius

  setRadiusMultiplier = (newRadiusMultiplier) ->
    radiusMultiplier = newRadiusMultiplier

  # tick function for force directed layout
  forceTick = (e) ->
    node
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)

    link
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

  # tick function for radial layout
  radialTick = (e) ->
    #node.each(moveToRadialLayout(e.alpha))
    node.each(keepCircleLayout(e.alpha))
    k = e.alpha * 0.1
    node
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)

    link
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

    if e.alpha < 0.03
      force.stop()
      updateLinks()

  keepCircleLayout = (alpha) ->
    (d) ->
      centerNode = groupCenters(d.id)
      if isRegister(d)
        k = alpha * 0.1
        d.x += (centerNode.x - d.x)# * k
        d.y += (centerNode.y - d.y)# * k
  # Adjusts x/y for each node to
  # push them towards appropriate location.
  # Uses alpha to dampen effect over time.
  moveToRadialLayout = () ->
    (d) ->
      centerNode = groupCenters(d.id)
      d.x = centerNode.x
      d.y = centerNode.y


  # Helper function that returns stroke color for
  # particular node.
  strokeFor = (d) ->
    d3.rgb(nodeColors(d.type)).darker().toString()

  # Mouseover tooltip function
  showDetails = (d,i) ->
    content = '<p class="main">' + if d.info? then d.info else d.id + '</span></p>'
    content += '<hr class="tooltip-hr">'
    content += '<p class="main">' + if d.size? then d.size else d.delay + '</span></p>'
    tooltip.showTooltip(content,d3.event)
    # higlight connected links
    if link
      link.attr("stroke", (l) ->
        if l.source == d || l.target == d then "#555" else "gray"
      )
        .attr("stroke-opacity", (l) ->
          if l.source == d or l.target == d then 1.0 else 0.5
        )

      # link.each (l) ->
      #   if l.source == d or l.target == d
      #     d3.select(this).attr("stroke", "#555")

    # highlight neighboring nodes
    # watch out - don't mess with node if search is currently matching
    node.style("stroke", (n) ->
      if (n.searched or neighboring(d, n)) then "#555" else strokeFor(n))
      .style("stroke-width", (n) ->
        if (n.searched or neighboring(d, n)) then 2.0 else 1.0)
  
    # highlight the node being moused over
    d3.select(this).style("stroke","black")
      .style("stroke-width", 2.0)

  # Mouseout function
  hideDetails = (d,i) ->
    tooltip.hideTooltip()
    # watch out - don't mess with node if search is currently matching
    node.style("stroke", (n) -> if !n.searched then strokeFor(n) else "#555")
      .style("stroke-width", (n) -> if !n.searched then 1.0 else 2.0)
    if link
      link.attr("stroke", "gray")
        .attr("stroke-opacity", 0.8)

  # Final act of Network() function is to return the inner 'network()' function.
  return network

# Activate selector button
activate = (group, link, defaultOption) ->
  d3.selectAll("##{group} a").classed("active", false)
  element = d3.select("##{group} ##{link}")
  if element.empty()
    element = d3.select("##{group} ##{defaultOption}")
  element.classed("active", true)

showRadialInput = ->
  $("#layoutRadius").show()

hideRadialInput = ->
  $("#layoutRadius").hide()

downloadSVG = ->
  #get svg element.
  svg = $("#vis")[0].childNodes[0]

  #get svg source.
  serializer = new XMLSerializer();
  source = serializer.serializeToString(svg);

  #add name spaces.
  if(!source.match('/^<svg[^>]+xmlns="http\:\/\/www\.w3\.org\/2000\/svg"/'))
    source = source.replace('/^<svg/', '<svg xmlns="http://www.w3.org/2000/svg"')
  if(!source.match('/^<svg[^>]+"http\:\/\/www\.w3\.org\/1999\/xlink"/'))
    source = source.replace('/^<svg/', '<svg xmlns:xlink="http://www.w3.org/1999/xlink"')

  #add xml declaration
  source = '<?xml version="1.0" standalone="no"?>\r\n' + source;

  #convert svg source to URI data scheme.
  url = "data:image/svg+xml;charset=utf-8,"+encodeURIComponent(source);

  downloadLink = document.createElement("a");
  downloadLink.href = url;
  downloadLink.download = "network.svg";
  document.body.appendChild(downloadLink);
  downloadLink.click();
  document.body.removeChild(downloadLink);

showHideRadialLayoutInput = (layout) ->
  if layout == "radial"
    showRadialInput()
  else
    hideRadialInput()

# https://stelfox.net/blog/2013/12/access-get-parameters-with-coffeescript/
getParams = () ->
  query = window.location.search.substring(1)
  raw_vars = query.split("&")
  params = {}
  params['port'] = window.location.port
  params['hostname'] = window.location.hostname
  for v in raw_vars
    [key, val] = v.split("=")
    params[key] = decodeURIComponent(val)
  params

generateGraphLink = (hostname, port) ->
  port = if port? then ':' + port else ''
  baseURL = hostname + port + '/?'
  parameters = {}
  parameters['graph'] = $('#song_select').val()
  parameters['layout'] = d3.selectAll("#layouts a").filter(".active").attr("id")
  parameters['movement'] = d3.selectAll("#movement a").filter(".active").attr("id")
  parameters['filter'] = d3.selectAll("#filters a").filter(".active").attr("id")
  parameters['sort'] = d3.selectAll("#sorts a").filter(".active").attr("id")
  parameters['charge'] = $("#charge").val()
  parameters['linkdistance'] = $("#linkDistance").val()
  parameters['linkstrength'] = $("#linkStrength").val()
  parameters['radius'] = $("#radiusMultiplier").val()
  parameters['layoutradius'] = $("#layoutRadiusInput").val()
  parameterList = []
  parameterList.push(paramName + '=' + value) for paramName, value of parameters
  console.log(parameterList.join('&'))
  return baseURL + parameterList.join('&')

copyToClipboard = (text) ->
  temp = document.createElement("input")
  temp.setAttribute("value", text)
  document.body.appendChild(temp)
  temp.select()
  document.execCommand("copy")
  document.body.removeChild(temp)

$ ->
  urlParams = getParams()
  console.log(urlParams)
  hostname = urlParams['hostname']
  port = urlParams['port']
  graph = urlParams['graph']
  layout = urlParams['layout']
  movement = urlParams['movement']
  filter = urlParams['filter']
  sort = urlParams['sort']
  chargeDividerInput = parseInt(urlParams['charge'], 10)
  chargeDivider = chargeDividerInput / 100.0
  linkDistanceInput = parseInt(urlParams['linkdistance'], 10) 
  linkDistanceMultiplier = linkDistanceInput / 100.0
  linkStrengthInput = parseInt(urlParams['linkstrength'], 10)
  linkStrengthValue = linkStrengthInput / 10.0
  radiusInput = parseInt(urlParams['radius'], 10)
  radiusMultiplier = radiusInput / 100.0
  layoutRadius = parseInt(urlParams['layoutradius'], 10)
  myNetwork = Network(layout:layout, movement: movement, filter: filter, sort: sort, chargeDivider: chargeDivider, linkDistanceMultiplier: linkDistanceMultiplier, linkStrengthValue: linkStrengthValue, radiusMultiplier: radiusMultiplier, radialLayoutRadius: layoutRadius)

  d3.selectAll("#layouts a").on "click", (d) ->
    newLayout = d3.select(this).attr("id")
    activate("layouts", newLayout)
    myNetwork.toggleLayout(newLayout)
    showHideRadialLayoutInput(newLayout)

  if layout?
    activate("layouts", layout, "force")
  showHideRadialLayoutInput(layout)

  d3.selectAll("#movement a").on "click", (d) ->
    newMovement = d3.select(this).attr("id")
    activate("movement", newMovement)
    myNetwork.toggleMovement(newMovement)

  if movement?
    activate("movement", movement, "dynamic")

  d3.selectAll("#filters a").on "click", (d) ->
    newFilter = d3.select(this).attr("id")
    activate("filters", newFilter)
    myNetwork.toggleFilter(newFilter)

  if filter?
    activate("filters", filter, "all")

  d3.selectAll("#sorts a").on "click", (d) ->
    newSort = d3.select(this).attr("id")
    activate("sorts", newSort)
    myNetwork.toggleSort(newSort)

  if sort?
    activate("sorts", sort, "none")

  $("#charge").on "input", (e) ->
    newCharge = $(this).val()
    myNetwork.setCharge(newCharge / 100.0)

  if type(chargeDividerInput) == "number" && !isNaN(chargeDividerInput)
    element = d3.select("#charge").property("value", chargeDividerInput)

  $("#linkDistance").on "input", (e) ->
    newLinkDistance = $(this).val()
    myNetwork.setLinkDistance(newLinkDistance / 100.0)

  if type(linkDistanceInput) == "number" && !isNaN(linkDistanceInput)
    d3.select("#linkDistance").property("value", linkDistanceInput)

  $("#linkStrength").on "input", (e) ->
    newLinkStrength = $(this).val()
    myNetwork.setLinkStrength(newLinkStrength / 10.0)

  if type(linkStrengthInput) == "number" && !isNaN(linkStrengthInput)
    d3.select("#linkStrength").property("value", linkStrengthInput)

  $("#radiusMultiplier").on "input", (e) ->
    newRadiusMultiplier = $(this).val()
    myNetwork.setRadiusMultiplier(newRadiusMultiplier / 100.0)

  if type(radiusInput) == "number" && !isNaN(radiusInput)
    d3.select("#radiusMultiplier").property("value", radiusInput)

  $("#layoutRadiusInput").on "input", (e) ->
    newRadius = $(this).val()
    myNetwork.setRadialLayoutRadius(newRadius)

  if type(layoutRadius) == "number" && !isNaN(layoutRadius)
    d3.select("#layoutRadiusInput").property("value", layoutRadius)
    console.log("layout radius:",layoutRadius)

  $("#song_select").on "change", (e) ->
    songFile = $(this).val()
    d3.json "data/json/#{songFile}", (json) ->
      myNetwork.updateData(json)
  
  $("#search").keyup () ->
    searchTerm = $(this).val()
    myNetwork.updateSearch(searchTerm)

  $("#showLegend").on "change", (e) ->
    checked = $(this).prop("checked")
    myNetwork.setLegendVisibility(checked)

  $("#download_button").on "click", (e) ->
    myNetwork.removeLegend()
    downloadSVG()
    myNetwork.updateLegend()

  $("#graphLink").on "click", (e) ->
    $(this).text('Copied to clipboard')
    link = generateGraphLink(hostname, port)
    copyToClipboard(link)

  updateGraphOptions = (options) ->
    console.log("updating graph options")
    console.log(options)
    select = d3.select("#song_select").selectAll("option").data(options.graphs).attr("value", (d) -> d).text((d) -> d)
    select.enter().append("option").attr("value", (d) -> d).text((d) -> d)
    select.exit().remove()

  checkOption = (e) ->
    if e == graph
      d3.select(this).attr("selected", "")
    else 
      d3.select(this).attr("selected", null)

  d3.json "data/data.json", (json) ->
    console.log("data called")
    updateGraphOptions(json)
    d3.select("#song_select").selectAll("option").each(checkOption)
    selectedGraph = $("#song_select").val()
    d3.json "data/json/#{selectedGraph}", (json) ->
      myNetwork("#vis", json)