require 'rubygems'
require 'json'

DEBUG=false
def parse(infh, outfh,  max_depth, max_byte_diff)
    infh.rewind
    stack=[]
    too_deep=0
    no_node=0
    nodes=Hash.new {|h,k| h[k]=false}
    edges=Hash.new {|h,k| h[k]=0}
    execution_start=JSON.parse( infh.readline )
    nodes[execution_start["from"]]=true
    current_node=execution_start["from"]
    # IO stream continues from line 2
    infh.each_line {|l|
        parsed=JSON.parse l
        if parsed["type"]=~/CALL/
            puts "CALL RAW from #{parsed["from"]} to #{parsed["to"]}" if DEBUG
            if nodes[parsed["to"]]
                puts "CALL from #{current_node} to OLD node #{parsed["to"]}" if DEBUG
                stack.push( [parsed["from"],current_node] )
                edges[[current_node, parsed["to"]]]+=1
                current_node=parsed["to"]
            else
                puts "CALL from #{current_node} to NEW node #{parsed["to"]}" if DEBUG
                stack.push( [parsed["from"],current_node] )
                nodes[parsed["to"]]=true
                edges[[current_node, parsed["to"]]]+=1
                current_node=parsed["to"]
            end
        elsif parsed ["type"]=~/RETURN/
            ret_addr=parsed["to"]
            puts "RET (raw) to #{ret_addr}" if DEBUG
            if stack.size < max_depth
                found=stack.any? {|ary|
                    caller_address=ary[0]
                    (diff=(ret_addr - caller_address)) < max_byte_diff && diff >= 0
                }
            else
                found=stack[(-max_depth)..-1].any? {|ary| 
                    caller_address=ary[0]
                    (diff=(ret_addr - caller_address)) < max_byte_diff && diff >= 0
                }
            end
            if found
                depth=1
                caller_address, owning_node=stack.pop 
                until ( (diff=(ret_addr - caller_address)) < max_byte_diff && diff >= 0 )
                    caller_address, owning_node=stack.pop 
                    depth+=1
                end
                puts "RET EDGE to #{owning_node} at depth #{depth}" if DEBUG
                edges[[current_node, owning_node]]+=1
                current_node=owning_node
            else
                caller_address, owning_node=stack.select {|ary| 
                    addr=ary[0]
                    (diff=(ret_addr - addr)) < max_byte_diff && diff >= 0
                }.last
                if caller_address
                    puts "RET EDGE to #{owning_node} at -#{stack.rindex(owning_node)} (too deep)" if DEBUG
                    edges[[current_node, owning_node]]+=1
                    current_node=owning_node
                    too_deep+=1
                else
                    puts "RET EDGE to node off stack #{ret_addr}" if DEBUG
                    edges[[current_node, ret_addr]]+=1
                    current_node=ret_addr
                    nodes[ret_addr]=true
                    no_node+=1
                end
            end
        else
            # module load
        end
    }
    puts "Using Depth #{max_depth} and bytediff #{max_byte_diff}"
    puts "#{nodes.keys.length} Nodes. #{too_deep} rets to node too deep in stack, #{no_node} rets to unknown node."
    outfh.puts "nodedef> name"
    nodes.each_key {|k| outfh.puts "#{k}"}
    outfh.puts "edgedef> node1,node2,freq INT default 0"
    edges.each {|k,v| outfh.puts "#{k[0]},#{k[1]},#{v}"}
    p edges.keys.select {|k| k[0]==2014547000 or k[1]==2014547000}
end

infh=File.open(ARGV[0],"rb")
outfh=File.open(ARGV[1], "wb") rescue $stdout
parse( infh, outfh, 4, 8 )
infh.close
outfh.close

