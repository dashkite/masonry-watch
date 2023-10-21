import $Path from "node:path"
import EventEmitter from "node:events"

Path =

  parse: (path) ->
    {dir, name, ext} = $Path.parse path
    path: path
    directory: dir
    name: name
    extension: ext


Event =

  normalize: ( event ) ->
    switch event
      when "unlink" then name: "rm", type: "file"
      when "addDir" then name: "add", type: "directory"
      when "unlinkDir" then name: "rm", type: "directory"
      else name: event, type: "file"

  # transform event arguments
  # allows us to go from binary to unary handler
  map: ( emitter, events ) ->
    result = new EventEmitter
    for name, handler of events
      emitter.on name, ( args... ) ->
        result.emit name, handler args...
    result

export { Path, Event }