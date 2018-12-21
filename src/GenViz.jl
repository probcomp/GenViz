module GenViz

using HTTP, JSON
using Suppressor
import HTTP.WebSockets.WebSocket
import UUIDs
import IJulia

# From Blink.jl
@static if Sys.isapple()
  launch(x) = run(`open $x`)
elseif Sys.islinux()
  launch(x) = run(`xdg-open $x`)
elseif Sys.iswindows()
  launch(x) = run(`cmd /C start $x`)
end

struct Viz
  clients::Dict{String, WebSocket}
  path::String
  info
  traces
  id
  server
  latestHTML::Ref{String}
  waitingForHTML::Condition

  Viz(server, path, info) = begin
    id = repr(UUIDs.uuid4())[7:end-2]
    v = new(Dict{String,WebSocket}(), path, info, Dict(), id, server, Ref(""), Condition())
    server.visualizations[id] = v
  end
end

addClient(viz::Viz, clientId, client) = begin
  viz.clients[clientId] = client
  write(client, json(Dict("action" => "initialize", "traces" => viz.traces, "info" => viz.info)))
end


struct VizServer
  visualizations::Dict{String, Viz}
  port
  connectionslock

  VizServer(port) = begin
    server = new(Dict{String, Viz}(), port, Base.Threads.SpinLock())
    @async @suppress HTTP.listen("127.0.0.1", port) do http
      if HTTP.WebSockets.is_upgrade(http.message)
        HTTP.WebSockets.upgrade(http) do client
          while isopen(client) && !eof(client)
            msg = JSON.parse(String(readavailable(client)))
            if msg["action"] == "connect"
              clientId = msg["clientId"]
              vizId = msg["vizId"]
              if haskey(server.visualizations, vizId)
                addClient(server.visualizations[vizId], clientId, client)
              end
            elseif msg["action"] == "disconnect"
              clientId = msg["clientId"]
              vizId = msg["vizId"]
              lock(server.connectionslock)
              delete!(server.visualizations[vizId].clients, clientId)
              unlock(server.connectionslock)
            elseif msg["action"] == "save"
                clientId = msg["clientId"]
                vizId = msg["vizId"]
                server.visualizations[vizId].latestHTML[] = msg["content"]
                notify(server.visualizations[vizId].waitingForHTML)
            end
          end
        end
      else
        req::HTTP.Request = http.message
        fullReqPath = HTTP.unescapeuri(req.target)
        vizId = split(fullReqPath[2:end], "/")[1]
        vizDir = server.visualizations[vizId].path
        restOfPath = fullReqPath[2+length(vizId):end]
        
        resp = if restOfPath == "" || restOfPath == "/"
          HTTP.Response(200, read(joinpath(vizDir, "index.html")))
        else
          file = joinpath(vizDir, restOfPath[2:end])
          isfile(file) ? HTTP.Response(200, read(file)) : HTTP.Response(404)
        end
        startwrite(http)
        write(http, resp.body)
      end
    end
    server
  end
end

broadcast(v::Viz, msg::Dict) = begin
  yield()
  for (cid, client) in v.clients
    yield()
    while islocked(v.server.connectionslock)
      yield()
    end
    if haskey(v.clients, cid) && isopen(client)
      try 
        write(client, json(msg))
      catch
      end
    end
    unlock(v.server.connectionslock)
  end
end

putTrace!(v::Viz, tId, t) = begin
  v.traces[tId] = t
  msg = Dict("action" => "putTrace", "tId" => tId, "t" => t)
  broadcast(v, msg)
end

deleteTrace!(v::Viz, tId) = begin
  delete!(v.traces, tId)
  msg = Dict("action" => "removeTrace", "tId" => tId)
  broadcast(v, msg)
end

# Blocks if no connections
getHTML(v::Viz) = begin
    println("GETTING HTML")
    while isempty(v.clients)
        println("No clients for this viz :(")
        yield()
    end
    broadcast(v, Dict("action" => "saveHTML"))
    println("Message broadcast... waiting for it to be received")
    wait(v.waitingForHTML)
    return v.latestHTML[]
end

# TODO: fix to work when not on localhost
vizURL(v::Viz) = "http://127.0.0.1:$(v.server.port)/$(v.id)/"

# Open a viz in a new browser window
openInBrowser(v::Viz) = launch(vizURL(v))

# Save to an HTML file
saveToFile(v::Viz, path) = begin
    html = getHTML(v)
    open(path, "w") do file
        write(file, html)
    end
end

# Display an iframe in a Jupyter Notebook. 
openInNotebook(v::Viz, height::Int64=600) = 
  display("text/html", "<iframe src=$(vizURL(v)) frameBorder=0 width=100% height=$(height)></iframe>")

# Display an iframe in a Jupyter Notebook, run some code to update the visualization,
# then freeze it. 
function displayInNotebook(f::Function, v::Viz, height::Int64=600)
    openInNotebook(v, height)
    f()
    html = getHTML(v)
    IJulia.clear_output()
    display("text/html", html)
end

# Capture the current state of the visualization in a Jupyter Notebook.
function displayInNotebook(v::Viz, height::Int64=600)
    displayInNotebook(v, height) do
        sleep(1)
    end
end

export Viz, putTrace!, deleteTrace!, VizServer, vizURL, displayInNotebook, openInNotebook, openInBrowser, saveToFile

end # module
