#!/bin/bash

main() {

    echo "===================================================================="
    echo " TRYING TO START ETCD NODE: ${ETCD_NAME} AS A MEMBER OF NEW CLUSTER"
    echo " SETTING: ETCD_INITIAL_CLUSTER_STATE=new"
    echo "===================================================================="
    
    export ETCD_INITIAL_CLUSTER_STATE=new
    etcd 2> >(tee >(tail -50 > stderr.log) >&2)
    
    etcd_exit_code=$?
    stderr_output=`cat stderr.log`
    
    echo "======================================="
    echo " EXIT CODE: $etcd_exit_code"
    echo "======================================="
    
    if [[ $etcd_exit_code -ne 0 && $stderr_output == *"has already been bootstrapped"* ]] 
    then
            member_id=`echo $stderr_output | grep "C | etcdmain: member .* has already been bootstrapped" | sed 's/.* member \(.*\) has already been bootstrapped/\1/'`
            
            echo "==================================================================="
            echo " RECOGNIZED ERROR: Member $member_id has already been bootstrapped"
            echo "==================================================================="
            
            cleanup_and_try_join_existing_cluster $member_id
            
    elif [[ $stderr_output == *"E | etcdserver: the member has been permanently removed from the cluster"* ]] 
    then        
            member_id=`etcdctl --endpoint $ETCD_OTHER_PEERS_CLIENT_URLS member list | grep " name=${ETCD_NAME} " | sed 's/\(.*\): .*/\1/'`
    
            echo "============================================================================"
            echo " RECOGNIZED ERROR: The member has been permanently removed from the cluster"
            echo "============================================================================"
            
            cleanup_and_try_join_existing_cluster $member_id
    
    elif [[ ( $etcd_exit_code -ne 0 && $etcd_exit_code -lt 126 ) ]] 
    then        
            member_id=`etcdctl --endpoint $ETCD_OTHER_PEERS_CLIENT_URLS member list | grep " name=${ETCD_NAME} " | sed 's/\(.*\): .*/\1/'`
    
            echo "==================================================================="
            echo " UNKNOWN ERROR. EXICT CODE: ${etcd_exit_code} BETWEEN 0 AND 126"
            echo "==================================================================="
            
            cleanup_and_try_join_existing_cluster $member_id
    
    fi

}

cleanup_and_try_join_existing_cluster() {

        echo "========================================================================="
        echo " GOING TO CLEAN UP MEMBER: ${member_id} AND TRY AGAIN"
        echo " MEMBER LIST:"        
        etcdctl --endpoint $ETCD_OTHER_PEERS_CLIENT_URLS member list
        
        echo " REMOVING MEMBER: ${member_id}"
        etcdctl --endpoint $ETCD_OTHER_PEERS_CLIENT_URLS member remove ${member_id}
        
        echo " ADDING NEW MEMBER: ${ETCD_NAME}"
        etcdctl --endpoint $ETCD_OTHER_PEERS_CLIENT_URLS member add ${ETCD_NAME} ${ETCD_INITIAL_ADVERTISE_PEER_URLS}
        
        echo " MEMBER LIST:"
        etcdctl --endpoint $ETCD_OTHER_PEERS_CLIENT_URLS member list
        
        echo " REMOVING DATA-DIR: ./${ETCD_NAME}.etcd/"
        rm -rf ./${ETCD_NAME}.etcd/*
        
        echo " UNSETING: ETCD_INITIAL_CLUSTER_TOKEN"
        unset ETCD_INITIAL_CLUSTER_TOKEN
        
        echo " SETTING: ETCD_INITIAL_CLUSTER_STATE=existing"
        export ETCD_INITIAL_CLUSTER_STATE=existing
        
        echo " TRYING TO START ETCD NODE: ${ETCD_NAME} AS A MEMBER OF EXISTING CLUSTER"
        echo "========================================================================="
        
        etcd
}

main
