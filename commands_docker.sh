##########
# docker #
##########
# starts a bash session in the image
docker run -it kamon/grafana_graphite /bin/bash
# starts a bash session in the container
docker exec -i -t 2bd978716de8 /bin/bash
docker exec -i -t `docker ps | grep -v CONTAINER | cut -d' ' -f1` /bin/bash
# lists the images
docker images

# cleanups
docker rm containerID
docker rmi imageID
# remove all containers, images and data
docker ps --all | grep -v CONTAINER | cut -d' ' -f1 | xargs docker rm
docker images | grep -v REPOSITORY | grep -v 8399049ce731 | perl -ne 'print "$1\n" if (m/(?:[ ]+ +)(?:[ ]+ +)(\w+)/)' | xargs docker rmi
rm -rf data/ log/

##################
# docker-compose #
##################
docker-compose build
docker-compose up
docker-compose stop





#####################
# grafana dashboard #
#####################
/opt/grafana/bin/grafana-cli plugins install jdbranham-diagram-panel
mv /var/lib/grafana/plugins/jdbranham-diagram-panel/ data/plugins/
exit


########################
# grafana diagram      #
# (mermaid.js syntax)  #
########################
# You can speficy a URL
# And link color to metrics
graph TD

RS-98(RS .98)--> RS-29(RS .29)

subgraph San Jose
RS-98 --> DS-71(DS .71)
RS-98 --> DS-110(DS .110)
end

subgraph Washington DC
RS-29 --> DS-25(DS .25)
RS-29 --> DS-46(DS .46)
end

click RS-29 "https://www.forgerock.com/platform/directory-services" "See status"
click RS-98 "https://www.forgerock.com/platform/directory-services" "See status"
click DS-71 "https://www.forgerock.com/platform/directory-services" "See status"
click DS-110 "https://www.forgerock.com/platform/directory-services" "See status"
click DS-25 "https://www.forgerock.com/platform/directory-services" "See status"
click DS-46 "https://www.forgerock.com/platform/directory-services" "See status"

style RS-98 fill:#f00
style DS-71 fill:#f00
style DS-110 fill:#f00

