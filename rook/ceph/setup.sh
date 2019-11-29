#!/bin/bash

echo 'Initial rook with cephfs in namespace storage'
kubectl apply -f 00_namespace.yaml
kubectl apply -f 01_common.yaml
kubectl apply -f 02_operator.yaml

function wait_for_pod_status_running {
    while true; do
        watch=$(kubectl get pod --namespace storage --no-headers | grep -vE 'Running|Completed' | wc -l)
        if [ "$watch" -ne "0" ]; then
            echo "Wait for all pods running"
            sleep 10
        else
            break
        fi
    done    
}

wait_for_pod_status_running
echo "Deploy rook & ceph cluster"
kubectl apply -f 03_cluster.yaml

wait_for_pod_status_running
echo "Deploy objectstore and objectstore user"
kubectl apply -f 04_objectstore.yaml
kubectl apply -f 05_object-user.yaml

wait_for_pod_status_running
echo "Deploy rool ceph toolbox"
kubectl apply -f toolbox.yaml

wait_for_pod_status_running
echo "Verify if CephObjectStorage is ready or not"
toolbox=`kubectl get pod --namespace storage | grep ceph-tool | awk '{print $1}' | head -n 1`
kubectl exec -it $toolbox --namespace storage -- bash -c "yum install --assumeyes s3cmd"
kubectl exec -it $toolbox --namespace storage -- bash -c "s3cmd mb --no-ssl --host=rook-ceph-rgw-ceph-object-store.storage --host-bucket=  s3://demo-bucket"
if [ "$?" -eq "0" ]; then
    kubectl exec -it $toolbox --namespace storage -- bash -c "s3cmd mb --no-ssl --host=rook-ceph-rgw-ceph-object-store.storage --host-bucket=  s3://demo-bucket"
    echo "CephObjectStorage is ready"
else
    echo "CephObjectStorage gets problem. Please check the deployment"
fi
