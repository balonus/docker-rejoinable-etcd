# docker-rejoinable-etcd

This image allows to start etcd2 member that can join static etcd cluster in automatic and flexible way. Without need for manual cluster reconfiguration when replacing failed cluster member. 

This image is intended for:

- only for [static etcd clusters](https://coreos.com/etcd/docs/latest/clustering.html#static) 
- HA setups with automatic failover of etcd nodes

## Rationale

We need flexible (elastic) etcd setup deployed in the cloud with automatic failover. What is more we prefer declarative deployment configuration (eg. Kubernetes yaml files) than scripting deployment. 

Standard etcd according to [documentation](https://coreos.com/etcd/docs/latest/runtime-configuration.html#replace-a-failed-machine), requires manual reconfiguration of cluster (remove failed node and then add new one). What is more it requires proper distniction between initial cluster bootstrap vs joining existing cluster ([initial cluster state documentation](https://coreos.com/etcd/docs/latest/configuration.html#initial-cluster-state)).  
 
Existing alternatives that we found do not fit our needs:

- [elastic etcd](https://github.com/sttts/elastic-etcd) very nice, quite generic and elastic approach, but it requires additional discovery service that we would like to avoid
- [etcd clustering in AWS](http://engineering.monsanto.com/2015/06/12/etcd-clustering/) doesn't require discovery service, but uses AWS API. We could replicate this approach and implement it in a similar way on Kubernetes with usage of K8S API. But we prefer to not depend on cloud infra API.
- [k8s etcd cluster](https://github.com/blended/k8s-etcd-cluster) it's external deployment scripting with distinction between bootstrap and further lifetime phases, which we want to avoid.
- [etcd hack k8s deploy](https://github.com/coreos/etcd/tree/v2.3.7/hack/kubernetes-deploy) very simple example which we started from, but unfortunatelly it doesn't provide failover.

## Concept

We provide entrypoint script in docker image that manages etcd node startup. It firstly tries to start and join new cluster. If joining new cluster fails, it tries to cleanup cluster membership of its name. And try to join existing cluster. 

Sequence:

1. Try to start etcd and join static cluster as it is new cluster (`export ETCD_INITIAL_CLUSTER_STATE=new`)
2. If previous step failed then try to remove from cluster previous member with the same name (`ETCD_NAME=xxx`)
3. Try to add to cluster new member with its name (`ETCD_NAME=xxx`)
4. Cleanup data dir (`rm -rf ./${ETCD_NAME}.etcd/*`)
5. Setup proper environment variables for joining existing cluster (`unset ETCD_INITIAL_CLUSTER_TOKEN`, `export ETCD_INITIAL_CLUSTER_STATE=existing`)
6. Try to start etcd and join static cluster as it is existing cluster (`ETCD_INITIAL_CLUSTER_STATE=existing`)

## Usage

Configuration should be passed via environment variables. All standard `ETCD_*` environment variables are supported ([documentation](https://coreos.com/etcd/docs/latest/configuration.html)).

Only [etcd static clusters](https://coreos.com/etcd/docs/latest/clustering.html#static) are supported. So `ETCD_INITIAL_CLUSTER` environment variable should be set properly. On the other hand `ETCD_INITIAL_CLUSTER_STATE` will be ignored (overriden by entrypoint script).

Additionally there should be set `ETCD_OTHER_PEERS_CLIENT_URLS` custom environment variable to point each instance to other instances client urls. This is used for 'cleaning' membership (removing/adding members with the same name). 

## How to run etcd cluster in dockers from command line?

```bash
docker run -it --name=etcd1 \
-e "ETCD_NAME=etcd1" \
-e "ETCD_ADVERTISE_CLIENT_URLS=http://192.168.99.100:1379" \
-e "ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379" \
-e "ETCD_INITIAL_ADVERTISE_PEER_URLS=http://192.168.99.100:1380" \
-e "ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380" \
-e "ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster-1" \
-e "ETCD_INITIAL_CLUSTER=etcd1=http://192.168.99.100:1380,etcd2=http://192.168.99.100:2380,etcd3=http://192.168.99.100:3380" \
-e "ETCD_OTHER_PEERS_CLIENT_URLS=http://192.168.99.100:2379,http://192.168.99.100:3379" \
-p 1379:2379 -p 1380:2380 balon/docker-rejoinable-etcd:v2.3.7


docker run -it --name=etcd2 \
-e "ETCD_NAME=etcd2" \
-e "ETCD_ADVERTISE_CLIENT_URLS=http://192.168.99.100:2379" \
-e "ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379" \
-e "ETCD_INITIAL_ADVERTISE_PEER_URLS=http://192.168.99.100:2380" \
-e "ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380" \
-e "ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster-1" \
-e "ETCD_INITIAL_CLUSTER=etcd1=http://192.168.99.100:1380,etcd2=http://192.168.99.100:2380,etcd3=http://192.168.99.100:3380" \
-e "ETCD_OTHER_PEERS_CLIENT_URLS=http://192.168.99.100:1379,http://192.168.99.100:3379" \
-p 2379:2379 -p 2380:2380 balon/docker-rejoinable-etcd:v2.3.7

docker run -it --name=etcd3 \
-e "ETCD_NAME=etcd3" \
-e "ETCD_ADVERTISE_CLIENT_URLS=http://192.168.99.100:3379" \
-e "ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379" \
-e "ETCD_INITIAL_ADVERTISE_PEER_URLS=http://192.168.99.100:3380" \
-e "ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380" \
-e "ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster-1" \
-e "ETCD_INITIAL_CLUSTER=etcd1=http://192.168.99.100:1380,etcd2=http://192.168.99.100:2380,etcd3=http://192.168.99.100:3380" \
-e "ETCD_OTHER_PEERS_CLIENT_URLS=http://192.168.99.100:1379,http://192.168.99.100:2379" \
-p 3379:2379 -p 3380:2380 balon/docker-rejoinable-etcd:v2.3.7
```

## How to run it in Kubernetes?

TODO

