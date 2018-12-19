module GenViz

using HTTP, JSON
import HTTP.WebSockets.WebSocket
import UUIDs

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

    Viz(server, path, info) = begin
        id = repr(UUIDs.uuid4())[7:end-2]
        v = new(Dict{String,WebSocket}(), path, info, Dict(), id, server)
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
        @async HTTP.listen("127.0.0.1", port) do http
            if HTTP.WebSockets.is_upgrade(http.message)
                HTTP.WebSockets.upgrade(http) do client
                    while isopen(client) && !eof(client)
                        msg = JSON.parse(String(readavailable(client)))
                        if msg["action"] == "connect"
                            println("Got connect message!")
                            clientId = msg["clientId"]
                            vizId = msg["vizId"]
                            if haskey(server.visualizations, vizId)
                                addClient(server.visualizations[vizId], clientId, client)
                            else
                                println("BAD VIZ-ID")
                            end
                        elseif msg["action"] == "disconnect"
                            clientId = msg["clientId"]
                            vizId = msg["vizId"]
                            lock(server.connectionslock)
                            delete!(server.visualizations[vizId].clients, clientId)
                            unlock(server.connectionslock)
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
        while islocked(server.connectionslock)
            yield()
        end
        if haskey(v.clients, cid) && isopen(client)
            try 
                write(client, json(msg))
            catch
            end
        end
        unlock(server.connectionslock)
    end
end

putTrace!(v::Viz, tId, t) = begin
    v.traces[tId] = t
  msg = Dict("action" => "putTrace", "tId" => tId, "t" => t)
    broadcast(v, msg)
end

deleteTrace!(v::Viz, tId::String) = begin
    delete!(v.traces, tId)
  msg = Dict("action" => "removeTrace", "tId" => tId)
    broadcast(v, msg)
end

export Viz, putTrace!, deleteTrace!, VizServer

end # module
