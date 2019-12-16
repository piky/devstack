declare -i y=0
str=""
node_name=""
str=$( vbmc list | grep node | awk '{print $2}' | wc -l)

while true
    if (($y==$str)); then break
    fi
    node_name="Clean node-$y"
    echo $node_name
    vbmc stop $node_name
    vbmc delete $node_name
   
    do y=y+1
done
	
