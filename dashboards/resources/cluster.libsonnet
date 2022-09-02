local defaultQueries = import './queries/cluster.libsonnet';
local defaultVariables = import './variables/cluster.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local table = g.panel.table;
local timeSeries = g.panel.timeSeries;

{
  local statPanel(title, unit, query) =
    stat.new(title)
    + stat.options.withColorMode('none')
    + stat.standardOptions.withUnit(unit)
    + stat.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
    + stat.queryOptions.withTargets([
      prometheus.new('${datasource}', query)
      + prometheus.withInstant(true),
    ]),

  local tsPanel =
    timeSeries {
      new(title):
        timeSeries.new(title)
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withAsTable()
        + timeSeries.options.legend.withDisplayMode('table')
        + timeSeries.options.legend.withPlacement('right')
        + timeSeries.options.legend.withCalcs(['lastNotNull'])
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withSpanNulls(true)
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'k8s-resources-cluster.json':
      // Allow overriding queries via $._queries.cluster, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'cluster')
      then $._queries.cluster
      else defaultQueries;

      // Allow overriding variables via $._variables.cluster, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'cluster')
      then $._variables.cluster($._config)
      else defaultVariables.cluster($._config);

      local links = {
        namespace: {
          alias: 'Namespace',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
          linkTooltip: 'Drill down to pods',
        },
        'Value #A': {
          alias: 'Pods',
          linkTooltip: 'Drill down to pods',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell_1' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
          decimals: 0,
        },
        'Value #B': {
          alias: 'Workloads',
          linkTooltip: 'Drill down to workloads',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-workloads-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell_1' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-workloads-namespace.json') },
          decimals: 0,
        },
      };


      local podWorkloadColumns = [
        'sum(kube_pod_owner{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
        'count(avg(namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster"}) by (workload, namespace)) by (namespace)' % $._config,
      ];

      local networkColumns = [
        'sum(irate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config,
        'sum(irate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config,
        'sum(irate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config,
        'sum(irate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config,
        'sum(irate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config,
        'sum(irate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config,
      ];

      local networkTableStyles = {
        namespace: {
          alias: 'Namespace',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
          linkTooltip: 'Drill down to pods',
        },
        'Value #A': {
          alias: 'Current Receive Bandwidth',
          unit: 'Bps',
        },
        'Value #B': {
          alias: 'Current Transmit Bandwidth',
          unit: 'Bps',
        },
        'Value #C': {
          alias: 'Rate of Received Packets',
          unit: 'pps',
        },
        'Value #D': {
          alias: 'Rate of Transmitted Packets',
          unit: 'pps',
        },
        'Value #E': {
          alias: 'Rate of Received Packets Dropped',
          unit: 'pps',
        },
        'Value #F': {
          alias: 'Rate of Transmitted Packets Dropped',
          unit: 'pps',
        },
      };

      local storageIOColumns = [
        'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config,
        'sum by(namespace) (rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config,
        'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config,
        'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config,
        'sum by(namespace) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config,
        'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config,
      ];

      local storageIOTableStyles = {
        namespace: {
          alias: 'Namespace',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
          linkTooltip: 'Drill down to pods',
        },
        'Value #A': {
          alias: 'IOPS(Reads)',
          unit: 'short',
          decimals: 0,
        },
        'Value #B': {
          alias: 'IOPS(Writes)',
          unit: 'short',
          decimals: 0,
        },
        'Value #C': {
          alias: 'IOPS(Reads + Writes)',
          unit: 'short',
          decimals: 0,
        },
        'Value #D': {
          alias: 'Throughput(Read)',
          unit: 'Bps',
        },
        'Value #E': {
          alias: 'Throughput(Write)',
          unit: 'Bps',
        },
        'Value #F': {
          alias: 'Throughput(Read + Write)',
          unit: 'Bps',
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Cluster' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-cluster.json']),
      )
      .addRow(
        (g.row('Headlines') +
         {
           height: '100px',
           showTitle: false,
         })
        .addPanel(
          g.panel('CPU Utilisation') +
          g.statPanel('cluster:node_cpu:ratio_rate5m{%(clusterLabel)s="$cluster"}' % $._config)
        )
        .addPanel(
          g.panel('CPU Requests Commitment') +
          g.statPanel('sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('CPU Limits Commitment') +
          g.statPanel('sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Utilisation') +
          g.statPanel('1 - sum(:node_memory_MemAvailable_bytes:sum{%(clusterLabel)s="$cluster"}) / sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s,%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Requests Commitment') +
          g.statPanel('sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Limits Commitment') +
          g.statPanel('sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % $._config)
        )
      )
      .addRow(
        g.row('CPU')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel(podWorkloadColumns + [
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #C': { alias: 'CPU Usage' },
            'Value #D': { alias: 'CPU Requests' },
            'Value #E': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #F': { alias: 'CPU Limits' },
            'Value #G': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory')
        .addPanel(
          g.panel('Memory Usage (w/o cache)') +
          // Not using container_memory_usage_bytes here because that includes page cache
          g.queryPanel('sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Requests')
        .addPanel(
          g.panel('Requests by Namespace') +
          g.tablePanel(podWorkloadColumns + [
            // Not using container_memory_usage_bytes here because that includes page cache
            'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace)' % $._config,
            'sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace) / sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace) / sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #C': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #D': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #E': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #F': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #G': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Current Network Usage')
        .addPanel(
          g.panel('Current Network Usage') +
          g.tablePanel(
            networkColumns,
            networkTableStyles
          ) +
          { interval: $._config.grafanaK8s.minimumTimeInterval },
        )
      )
      .addRow(
        g.row('Bandwidth')
        .addPanel(
          g.panel('Receive Bandwidth') +
          g.queryPanel('sum(irate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
        .addPanel(
          g.panel('Transmit Bandwidth') +
          g.queryPanel('sum(irate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Average Container Bandwidth by Namespace')
        .addPanel(
          g.panel('Average Container Bandwidth by Namespace: Received') +
          g.queryPanel('avg(irate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
        .addPanel(
          g.panel('Average Container Bandwidth by Namespace: Transmitted') +
          g.queryPanel('avg(irate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Rate of Packets')
        .addPanel(
          g.panel('Rate of Received Packets') +
          g.queryPanel('sum(irate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('pps') },
        )
        .addPanel(
          g.panel('Rate of Transmitted Packets') +
          g.queryPanel('sum(irate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('pps') },
        )
      )
      .addRow(
        g.row('Rate of Packets Dropped')
        .addPanel(
          g.panel('Rate of Received Packets Dropped') +
          g.queryPanel('sum(irate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('pps') },
        )
        .addPanel(
          g.panel('Rate of Transmitted Packets Dropped') +
          g.queryPanel('sum(irate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('pps') },
        )
      )
      .addRow(
        g.row('Storage IO')
        .addPanel(
          g.panel('IOPS(Reads+Writes)') +
          g.queryPanel('ceil(sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s])))' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('short'), decimals: -1 },

        )
        .addPanel(
          g.panel('ThroughPut(Read+Write)') +
          g.queryPanel('sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Storage IO - Distribution')
        .addPanel(
          g.panel('Current Storage IO') +
          g.tablePanel(
            storageIOColumns,
            storageIOTableStyles
          ) +
          {
            sort: {
              col: 4,
              desc: true,
            },
          },
        },
      };

      local panels = [
        statPanel(
          'CPU Utilisation',
          'percentunit',
          queries.cpuUtilisation($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Requests Commitment',
          'percentunit',
          queries.cpuRequestsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Limits Commitment',
          'percentunit',
          queries.cpuLimitsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Utilisation',
          'percentunit',
          queries.memoryUtilisation($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Requests Commitment',
          'percentunit',
          queries.memoryRequestsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Limits Commitment',
          'percentunit',
          queries.memoryLimitsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        tsPanel.new('CPU Usage')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.cpuUsageByNamespace($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('CPU Quota')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.podsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.workloadsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuUsageByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuRequestsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuLimitsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuUsageVsLimits($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
              'Time 7': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              'Time 7': 6,
              namespace: 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'Value #G': 14,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Pods',
              'Value #B': 'Workloads',
              'Value #C': 'CPU Usage',
              'Value #D': 'CPU Requests',
              'Value #E': 'CPU Requests %',
              'Value #F': 'CPU Limits',
              'Value #G': 'CPU Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        tsPanel.new('Memory')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryUsageByNamespace($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Memory Requests by Namespace')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.podsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.workloadsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryUsageByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryRequestsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryLimitsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryUsageVsLimits($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
              'Time 7': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              'Time 7': 6,
              namespace: 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'Value #G': 14,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Pods',
              'Value #B': 'Workloads',
              'Value #C': 'Memory Usage',
              'Value #D': 'Memory Requests',
              'Value #E': 'Memory Requests %',
              'Value #F': 'Memory Limits',
              'Value #G': 'Memory Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Usage',
            },
            properties: [
              {
                id: 'unit',
                value: 'bytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Requests',
            },
            properties: [
              {
                id: 'unit',
                value: 'bytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Limits',
            },
            properties: [
              {
                id: 'unit',
                value: 'bytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        table.new('Current Network Usage')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.networkReceiveBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkTransmitBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkReceivePackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkTransmitPackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkReceivePacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkTransmitPacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              namespace: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Current Receive Bandwidth',
              'Value #B': 'Current Transmit Bandwidth',
              'Value #C': 'Rate of Received Packets',
              'Value #D': 'Rate of Transmitted Packets',
              'Value #E': 'Rate of Received Packets Dropped',
              'Value #F': 'Rate of Transmitted Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/Bandwidth/',
            },
            properties: [
              {
                id: 'unit',
                value: $._config.units.network,
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Packets/',
            },
            properties: [
              {
                id: 'unit',
                value: 'pps',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkTransmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Namespace: Received')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgContainerReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Namespace: Transmitted')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgContainerTransmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.rateOfReceivedPackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.rateOfTransmittedPackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.rateOfReceivedPacketsDropped($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.rateOfTransmittedPacketsDropped($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('IOPS(Reads+Writes)')
        + tsPanel.standardOptions.withUnit('iops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.iopsReadsWrites($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('ThroughPut(Read+Write)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.throughputReadWrite($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Storage IO')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.iopsReads($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.iopsWrites($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.iopsReadsWritesCombined($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.throughputRead($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.throughputWrite($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.throughputReadWriteCombined($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              namespace: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'IOPS(Reads)',
              'Value #B': 'IOPS(Writes)',
              'Value #C': 'IOPS(Reads + Writes)',
              'Value #D': 'Throughput(Read)',
              'Value #E': 'Throughput(Write)',
              'Value #F': 'Throughput(Read + Write)',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/IOPS/',
            },
            properties: [
              {
                id: 'unit',
                value: 'iops',
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Throughput/',
            },
            properties: [
              {
                id: 'unit',
                value: $._config.units.network,
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Cluster' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-cluster.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=6)),
  },
}
