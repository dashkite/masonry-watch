import * as Fn from "@dashkite/joy/function"
import { generic } from "@dashkite/joy/generic"
import * as It from "@dashkite/joy/iterable"
import * as Type from "@dashkite/joy/type"
import * as DRN from "@dashkite/drn-sky"
import * as SNS from "@dashkite/dolores/sns"
import chokidar from "chokidar"
import { Path, Event } from "./helpers"

watcher = ( build ) ->
  do ({ watcher } = {}) ->
    build.root ?= "."
    watcher = chokidar.watch build.glob, 
      cwd: build.root
      usePolling: true
    It.events "all", 
      Event.map watcher,
        all: ( event, path ) ->
          { 
            event: ( Event.normalize event )
            root: build.root # backward compatibility
            path
            build 
          }

# TODO add this to joy/iterable
merge = ( reactors ) ->
  do ({ q } = {}) ->
    q = It.Queue.create()
    for reactor in reactors
      do ( reactor, { product } = {}) ->
        for await product from reactor
          q.enqueue product
    loop yield await q.dequeue()

# TODO replace Joy version with something more like this?
_match = do ({ match } = {}) ->

  match = generic name: "match"

  generic match, Type.isString, Type.isDefined, Type.isObject,
    ( key, value, context ) -> context[ key ] == value

  generic match, Type.isString, Type.isArray, Type.isObject,
    ( key, values, context ) -> context[ key ] in values

  generic match, Type.isObject, Type.isObject,
    ( query, context ) ->
      for key, value of query
        return false if !( match key, value, context )
      true

  Fn.curry Fn.binary match

match = do ({ match } = {}) ->

  match = generic name: "match"

  generic match, Type.isObject, Type.isFunction,
    ( query, handler ) ->
      Fn.tee ( context ) ->
        if ( _match query, context.event )
          handler context
      
  generic match, Type.isObject, Type.isArray,
      ( query, handlers ) -> 
        match query, Fn.flow handlers
  
  match

watch = ( reactor ) ->
  for await { event, path, build } from reactor
    yield {
      event
      source: Path.parse path
      build
    }

isGlob = ( value ) -> value?.glob?

glob = do ({ glob } = {}) ->

  glob = generic name: "glob"

  generic glob, Type.isObject, ( targets ) -> ->
    do ( reactors = [] ) ->
      for target, builds of targets
        for build in builds
          build.preset ?= target
          reactors.push watcher { build..., target }
      watch merge reactors

  generic glob, isGlob, ( target ) -> ->
    watch watcher target
  
  glob

notify = do ({ topic } = {}) ->
  Fn.tee ({ source, event, module }) -> 
    # TODO add source path
    # TODO how to determine whether the souce is “local”?
    topic ?= await SNS.create await DRN.resolve "drn:topic/dashkite/development"
    SNS.publish topic, { event..., source, module: module.name }

export { glob, match, notify }
export default { glob, match, notify }