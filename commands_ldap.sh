#!/bin/bash -e

# LDAP search
target/opendj_auto/bin/ldapsearch -p 1389 -D "cn=Directory Manager" -w password -b "dc=example,dc=com" "(uid=bjensen)"
curl "http://localhost:8080/api/users/bjensen?_prettyPrint=true"

target/opendj_auto/bin/ldapsearch -p 1389 -D "cn=Directory Manager" -w password -b "dc=example,dc=com" "&"
curl "http://localhost:8080/api/users?_queryFilter=true&_prettyPrint=true"

target/opendj_auto/bin/ldapsearch -p 1389 -D "cn=Directory Manager" -w password -b "cn=schema" -s base "(objectclass=*)" +


# LDAP modify
# create user
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password -f ~/ldif/newuser.ldif
# create user inline
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password <<END_OF_COMMAND_INPUT
dn: cn=A1,dc=example,dc=com
objectclass:top
objectclass:organizationalperson
objectclass:inetorgperson
objectclass:person
sn:User
cn:Test User
description:1
description:2
mail:bla@example.com
telephonenumber:+33165990803
END_OF_COMMAND_INPUT
# add description attribute
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password -f ~/ldif/newdesc.ldif
# modify description 1 attribute
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password -f ~/ldif/moddesc1.ldif
# modify description 2 attribute
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password -f ~/ldif/moddesc2.ldif
# make description attribute multivalued
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password -f ~/ldif/multivalueddesc.ldif
# delete user
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password -f ~/ldif/deluser.ldif
# display the newly added user
target/opendj_auto/bin/ldapsearch -p 1389 -D "cn=Directory Manager" -w password -b "dc=example,dc=com" "(uid=newuser)"

# modify, delete+add
target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password <<END_OF_COMMAND_INPUT
dn: cn=schema
changetype: modify
delete: attributeTypes
attributeTypes: ( 1.3.6.1.4.1.26027.1.1.169 NAME 'ds-task-import-ldif-file' EQUALITY caseExactMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 X-ORIGIN 'OpenDS Directory Server' )
-

add: attributeTypes
attributeTypes: ( 1.3.6.1.4.1.26027.1.1.169 NAME 'ds-task-import-ldif-file' EQUALITY caseExactMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 X-ORIGIN 'OpenDS Directory Server' X-COUCOU 'JNR was here')
END_OF_COMMAND_INPUT


# REST using authentication
curl --header "X-OpenIDM-Username: name" --header "X-OpenIDM-Password: pass" "http://localhost:8080/api/users/bjensen?_prettyPrint=true"
curl "http://bjensen:hifalutin@localhost:8080/api/users?_queryFilter=true&_prettyPrint=true"
curl "http://bjensen:hifalutin@localhost:8080/api/users/newuser?_prettyPrint=true"


# dsconfig HTTP Connection Handler
# a bidouiller tools.properties dans le home???
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X     --displayCommand --advanced

target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-connection-handler-prop --handler-name "HTTP Connection Handler"    --set enabled:true
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-connection-handler-prop --handler-name "HTTP Connection Handler"    --set authentication-required:false
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-log-publisher-prop      --publisher-name "File-Based HTTP Access Logger" --set enabled:true
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-log-publisher-prop      --publisher-name "File-Based Access Logger" --set suppress-internal-operations:false
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-log-publisher-prop      --publisher-name "File-Based Access Logger" --set log-format:"cs-host c-ip cs-username datetime cs-method cs-uri-query cs-version sc-status sc-bytes cs(User-Agent) x-connection-id" &

# enable debug logs
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-log-publisher-prop      --publisher-name "File-Based Debug Logger"  --set default-debug-level:all --set enabled:true
# create debug target
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  create-debug-target         --publisher-name "File-Based Debug Logger"  --set debug-level:all --type generic --target-name org.opends.server.api

# stats / Performance
target/opendj_auto/bin/ldapsearch -p 1389 -D "cn=Directory Manager" -w password -b "cn=monitor" "(objectClass=ds-connectionhandler-statistics-monitor-entry)"
target/opendj_auto/bin/ldapsearch -p 1389 -D "cn=Directory Manager" -w password -b "cn=HTTP Connection Handler 0.0.0.0 port 8080 Statistics,cn=monitor" "(objectClass=*)"
target/opendj_auto/bin/modrate -p 1500 -D "cn=directory manager" -w password -F -c 4 -t 4 -b "uid=user.%d,ou=people,dc=example,dc=com"     -g "rand(0,1000)" -g "randstr(16)" 'description:%2$s'


# status
target/opendj_auto/bin/status        -w password -X    -D "cn=Directory Manager"
# replication
target/opendj_auto/bin/dsreplication -w password -X -n -b "dc=example,dc=com" status
target/opendj_auto/bin/control-panel -w password -X    -D "cn=Directory Manager"


# Processing time test
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-connection-handler-prop --handler-name "HTTP Connection Handler"    --set enabled:true
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-connection-handler-prop --handler-name "HTTP Connection Handler"    --set authentication-required:false
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-log-publisher-prop      --publisher-name "File-Based HTTP Access Logger" --set enabled:true
target/opendj_auto/bin/dsconfig --hostname localhost -p 4444 -D "cn=Directory Manager" -w password -X -n  set-log-publisher-prop      --publisher-name "File-Based Access Logger" --set suppress-internal-operations:false
curl "http://bjensen:hifalutin@localhost:8080/api/users?_queryFilter=true&_prettyPrint=true"
for i in {5..12}; do grep conn=${i} target/opendj_auto/logs/access | perl -ne 'print "$1\n" if (m/etime=(\d+)/);' | paste -sd+ | bc; done


target/opendj_auto/bin/ldapmodify -p 1389 -D "cn=Directory Manager" -w password -f ~/ldif/OPEND-948_aci.ldif
target/opendj_auto/bin/ldapsearch -p 1389 -b "dc=example,dc=com" "&"
target/opendj_auto/bin/ldapsearch -p 1389 -b "cn=this does not exist,ou=people,dc=example,dc=com" "objectclass=*"
target/opendj_auto/bin/ldapdelete -p 1389 "uid=user.9,ou=people,dc=example,dc=com"
target/opendj_auto/bin/ldapmodify -p 1389 -f ~/ldif/OPEND-948_modify_user_entry.ldif
target/opendj_auto/bin/ldapsearch -p 1389 -b "ou=people,dc=example,dc=com" "objectclass=*" debugsearchindex
target/opendj_auto/bin/ldapmodify -p 1389 -f ~/ldif/OPEND-948_existing_user_entry.ldif

# replication

target/opendj_auto/bin/modrate -p 1500 -D "cn=directory manager" -w password --noRebind --numConnections 4 --numThreads 4 --maxIterations 16  \
                                       -b "uid=user.%d,ou=people,dc=example,dc=com" --argument "inc(0,500000)" --argument "randstr(16)" 'description:%2$s'
# search on changelog
target/opendj_auto/bin/ldapsearch -p 1501 -D "cn=Directory Manager" -w password -b "cn=changelog" "&" "*" "+" | less
# persistent search on changelog
target/opendj_auto/bin/ldapsearch -p 1501 -D "cn=Directory Manager" -w password -C ps:all -b "cn=changelog" "&" "(objectclass=*)" | less
# search on changelog with changenumber
target/opendj_auto/bin/ldapsearch -p 1501 -D "cn=Directory Manager" -w password -b "cn=changelog" "changenumber>=1" "*" "+"
# search on changelog with changelogcookie
target/opendj_auto/bin/ldapsearch -p 1501 -D "cn=Directory Manager" -w password -b "cn=changelog" "changelogcookie=...cookie..." "*" "+"
# search on lastchangenumber virtual attribute
target/opendj_auto/bin/ldapsearch -p 1501 -D "cn=Directory Manager" -w password -b "" -s base "&" lastchangenumber



OPENDJ_JAVA_ARGS="-agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=y"
SCRIPT_ARGS="-agentlib:jdwp=transport=dt_socket,address=8001,server=y,suspend=y"





TODO JNR:
- include real processing time in HTTP etime
- hook grizzly logs into OpenDJ server logs
- only enable the HTTP access log publishers when the HTTP handler is started
- Enable HTTP conn handler by default
	- Change setup to offer a port for it
	- fix running tests
- Bug SEARCH RES after DISCONNECT in HTTP conn handler log
- http://docs.oracle.com/javaee/6/api/javax/servlet/ServletRequest.html#getRemoteHost%28%29:
	"If the engine cannot or chooses not to resolve the hostname (to improve performance), this method returns the dotted-string form of the IP address."
	How to configure this with Grizzly?
