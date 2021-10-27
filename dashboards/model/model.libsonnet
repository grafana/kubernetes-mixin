{
    // On record for each k8s kind.
    //
    // Records should be of the format:
    // {
    //   icon: ...,
    //   namespaced: <bool>    - if this object is in a namespace.
    //   info: [...],          - list of metrics to render as info
    //   relationships: [...], - list of one-to-many relationships for this kind.
    //   metrics: [...],       - list of meaninful metrics for this kind.
    // }
    kinds: {
        ConfigMap: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/cm-128.png",
            namespaced: true,
            info: [
                {
                    name: "Created On",
                    type: "datetime",
                    metric: "kube_configmap_created"
                },
                {
                    name: "Resource Version",
                    type: "number",
                    metric: "kube_configmap_metadata_resource_version",
                },
            ],
            relationships: [],
        },
        CronJob: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/cronjob-128.png",
            namespaced: true,
            info: [
                {
                    name: 'Schedule',
                    type: 'label',
                    metric: 'kube_cronjob_info',
                    label: 'schedule',
                },
                {
                    name: 'Concurrency Policy',
                    type: 'label',
                    metric: 'kube_cronjob_info',
                    label: 'concurrency_policy',
                },
            ],
            relationships: [
                // TODO find a metric to relate CronJobs to Jobs.
            ],
        },
        DaemonSet: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/ds-128.png",
            namespaced: true,
            info: [],
            relationships: [
                {
                    one: 'DaemonSet',
                    many: 'Pod',
                    one_label: 'owner_name',
                    metric: 'kube_pod_owner',
                    filters: ['owner_is_controller="true"', 'owner_kind="DaemonSet"'],
                },
            ],
        },
        Job: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/job-128.png",
            namespaced: true,
            info: [],
            relationships: [
                {
                    one: 'Job',
                    many: 'Pod',
                    one_label: 'owner_name',
                    metric: 'kube_pod_owner',
                    filters: ['owner_is_controller="true"', 'owner_kind="Job"'],
                },
            ],
        },
        Namespace: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/ns-128.png",
            namespaced: false,
            info: [],
            relationships: [
                {
                    one: 'Namespace',
                    many: 'ConfigMap',
                    metric: 'kube_configmap_info',
                },
                {
                    one: 'Namespace',
                    many: 'CronJob',
                    metric: 'kube_cronjob_info',
                },
                {
                    one: 'Namespace',
                    many: 'DaemonSet',
                    metric: 'kube_daemonset_info',
                },
                {
                    one: 'Namespace',
                    many: 'Deployment',
                    metric: 'kube_deployment_info',
                },
                {
                    one: 'Namespace',
                    many: 'StatefulSet',
                    metric: 'kube_statefulset_info',
                },
                {
                    one: 'Namespace',
                    many: 'Pod',
                    metric: 'kube_pod_info',
                },
            ],
        },
        Node: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/infrastructure_components/unlabeled/node-128.png",
            namespaced: false,
            info: [
                {
                    name: 'Internal IP',
                    type: 'label',
                    metric: 'kube_node_info',
                    label: 'internal_ip',
                },
                {
                    name: 'Pod CIDR',
                    type: 'label',
                    metric: 'kube_node_info',
                    label: 'pod_cidr ',
                },
                {
                    name: 'Kubelet Version',
                    type: 'label',
                    metric: 'kube_node_info',
                    label: 'kubelet_version',
                },
                {
                    name: 'KubeProxy Version',
                    type: 'label',
                    metric: 'kube_node_info',
                    label: 'kubeproxy_version',
                },
                {
                    name: 'Kernel Version',
                    type: 'label',
                    metric: 'kube_node_info',
                    label: 'kernel_version',
                },
            ],
            relationships: [
                 {
                    one: 'Node',
                    many: 'Pod',
                    metric: 'kube_pod_info',
                },
            ],
        },
        Pod: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/pod-128.png",
            namespaced: true,
            info: [
                {
                    name: 'Pod IP',
                    type: 'label',
                    metric: 'kube_pod_info',
                    label: 'pod_ip',
                },
            ],
            relationships: [
                {
                    one: 'Pod',
                    many: 'Persistentvolumeclaims',
                    metric: 'kube_pod_spec_volumes_persistentvolumeclaims_info',
                },
            ],
        },
        ReplicaSet: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/rs-128.png",
            namespaced: true,
            info: [],
            relationships: [
                {
                    one: 'ReplicaSet',
                    many: 'Pod',
                    one_label: 'owner_name',
                    metric: 'kube_pod_owner',
                    filters: ['owner_is_controller="true"', 'owner_kind="ReplicaSet"'],
                },
            ],
        },
        StatefulSet: {
            icon: "https://github.com/kubernetes/community/raw/master/icons/png/resources/unlabeled/sts-128.png",
            namespaced: true,
            info: [],
            relationships: [
                {
                    one: 'StatefulSet',
                    many: 'Pod',
                    one_label: 'owner_name',
                    metric: 'kube_pod_owner',
                    filters: ['owner_is_controller="true"', 'owner_kind="StatefulSet"'],
                },
            ],
        },
    },

    relationships: std.flattenArrays([
        $.kinds[k].relationships
        for k in std.objectFields($.kinds)
    ]),
}