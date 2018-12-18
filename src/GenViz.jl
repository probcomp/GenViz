module GenViz

using HTTP, JSON
import HTTP.WebSockets.WebSocket
import Random

# From Blink.jl
@static if Sys.isapple()
    launch(x) = run(`open $x`)
elseif Sys.islinux()
    launch(x) = run(`xdg-open $x`)
elseif Sys.iswindows()
    launch(x) = run(`cmd /C start $x`)
end

struct Viz
    connections::Dict{String,WebSocket}

    Viz(directory) = Viz(directory, 8000)
    Viz(directory, port) = begin
        connected = Condition()
        v = new(Dict{String,WebSocket}())

        @async HTTP.listen("127.0.0.1", port) do http
            if HTTP.WebSockets.is_upgrade(http.message)
                HTTP.WebSockets.upgrade(http) do client
                    while !eof(client)
                        msg = JSON.parse(String(readavailable(client)))
                        if msg["action"] == "connect"
                            clientId = msg["id"]
                            v.connections[clientId] = client
                            notify(connected)
                        elseif msg["action"] == "disconnect"
                            delete!(v.connections, msg["id"])
                        end
                    end
                end
            else
                req::HTTP.Request = http.message
                resp = if req.target == "/"
                   HTTP.Response(200, read(joinpath(@__DIR__, directory, "index.html")))
               else
                   file = joinpath(@__DIR__, directory, HTTP.unescapeuri(req.target[2:end]))
                   isfile(file) ? HTTP.Response(200, read(file)) : HTTP.Response(404)
               end
               startwrite(http)
               write(http, resp.body)
           end
       end
       sleep(1)
       launch("http://localhost:$(port)/")
       wait(connected)
       v
    end
end

broadcast(v::Viz, msg::Dict) = begin
    for (cid, client) in v.connections
        if isopen(client)
            write(client, json(msg))
        end
    end
end

setTrace(v::Viz, tId, t) = begin
    msg = Dict("action" => "setTrace", "tId" => tId, "t" => t)
    broadcast(v, msg)
end

deleteTrace(v::Viz, tId::String) = begin
    msg = Dict("action" => "removeTrace", "tId" => tId)
   broadcast(v, msg)
end

init(v::Viz, args) = begin
    msg = Dict("action" => "initialize", "args" => args)
   broadcast(v, msg)
end

export Viz, setTrace, deleteTrace, init

end # module
