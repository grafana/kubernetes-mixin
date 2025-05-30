local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local gauge = g.panel.gauge;
local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

{
  local tsPanel =
    timeSeries {
      new(title):
        timeSeries.new(title)
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withAsTable()
        + timeSeries.options.legend.withDisplayMode('table')
        + timeSeries.options.legend.withPlacement('right')
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'pod-total.json':
      local variables = {
        datasource:
          var.datasource.new('datasource', 'prometheus')
          + var.datasource.withRegex($._config.datasourceFilterRegex)
          + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
          + var.datasource.generalOptions.withLabel('Data source')
          + {
            current: {
              selected: true,
              text: $._config.datasourceName,
              value: $._config.datasourceName,
            },
          },

        cluster:
          var.query.new('cluster')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            $._config.clusterLabel,
            'up{%(cadvisorSelector)s}' % $._config,
          )
          + var.query.generalOptions.withLabel('cluster')
          + var.query.refresh.onTime()
          + (
            if $._config.showMultiCluster
            then var.query.generalOptions.showOnDashboard.withLabelAndValue()
            else var.query.generalOptions.showOnDashboard.withNothing()
          )
          + var.query.withSort(type='alphabetical'),

        namespace:
          var.query.new('namespace')
          + var.query.selectionOptions.withIncludeAll(true, '.+')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'namespace',
            'container_network_receive_packets_total{%(clusterLabel)s="$cluster"}' % $._config,
          )
          + var.query.generalOptions.withCurrent('kube-system')
          + var.query.generalOptions.withLabel('namespace')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),

        pod:
          var.query.new('pod')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'pod',
            'container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}' % $._config,
          )
          + var.query.generalOptions.withCurrent('kube-system')
          + var.query.generalOptions.withLabel('pod')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),
      };

      local panels = [
        gauge.new('Current Rate of Bytes Received')
        + gauge.standardOptions.withDisplayName('$pod')
        + gauge.standardOptions.withUnit('Bps')
        + gauge.standardOptions.withMin(0)
        + gauge.standardOptions.withMax(10000000000)  // 10GBs
        + gauge.standardOptions.thresholds.withSteps([
          {
            color: 'dark-green',
            index: 0,
            value: null,  // 0GBs
          },
          {
            color: 'dark-yellow',
            index: 1,
            value: 5000000000,  // 5GBs
          },
          {
            color: 'dark-red',
            index: 2,
            value: 7000000000,  // 7GBs
          },
        ])
        + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + gauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        gauge.new('Current Rate of Bytes Transmitted')
        + gauge.standardOptions.withDisplayName('$pod')
        + gauge.standardOptions.withUnit('Bps')
        + gauge.standardOptions.withMin(0)
        + gauge.standardOptions.withMax(10000000000)  // 10GBs
        + gauge.standardOptions.thresholds.withSteps([
          {
            color: 'dark-green',
            index: 0,
            value: null,  // 0GBs
          },
          {
            color: 'dark-yellow',
            index: 1,
            value: 5000000000,  // 5GBs
          },
          {
            color: 'dark-red',
            index: 2,
            value: 7000000000,  // 7GBs
          },
        ])
        + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + gauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Pod' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['pod-total.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.pod])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
