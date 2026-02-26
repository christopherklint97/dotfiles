kubeconf() {
    KC=$HOME/.kube/config
    rm -f $KC
    convox rack kubeconfig -r $1 | sed "s/rack/$1/" | grep -v current-context > $HOME/.kube/$1
    yq e -i ".contexts[0].context.user = \"$1\"" $HOME/.kube/$1
    yq e -i ".users[0].name = \"$1\"" $HOME/.kube/$1
    KUBECONFIG=$KC:$(find $HOME/.kube -type f -maxdepth 1 | tr '\n' ':')
    kubectl config view --flatten > $KC
    export KUBECONFIG=$HOME/.kube/config
    kubectl config use-context convox@$1
}
