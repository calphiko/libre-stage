<script lang="ts">
	import { onMount } from 'svelte';
	import * as echarts from 'echarts/core';
	import { BarChart } from 'echarts/charts';
	import { GridComponent, TooltipComponent } from 'echarts/components';
	import { CanvasRenderer } from 'echarts/renderers';
	import { isDarkMode } from '$lib/themeStore';

	let {
		data = [],
		period = 'month',
		title = 'Proben / Monat',
		valueKey = 'Proben',
		valueFormatter = (value) => `${value} Proben`,
		color = '#22c55e'
	} = $props();

	echarts.use([BarChart, GridComponent, TooltipComponent, CanvasRenderer]);

	let chartRef: HTMLDivElement;
	let chart: echarts.ECharts | null = null;

	let chartTheme = $derived({
		textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
		axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
		tooltipBackground: $isDarkMode ? '#334155' : '#ffffff'
	});

	function buildOptions() {
		const values = Array.isArray(data) ? data : [];
		const periodLabel = period === 'year' ? 'Jahr' : 'Monat';
		const chartTitle = title || `Proben / ${periodLabel}`;

		if (values.length === 0) {
			return {
				graphic: {
					type: 'text',
					left: 'center',
					top: 'middle',
					style: {
						text: 'Noch keine Daten vorhanden',
						fill: chartTheme.textColor,
						fontSize: 12
					}
				}
			};
		}

		return {
			tooltip: {
				trigger: 'axis',
				axisPointer: { type: 'shadow' },
				backgroundColor: chartTheme.tooltipBackground,
				borderColor: chartTheme.axisLineColor,
				textStyle: { color: chartTheme.textColor },
				formatter: (params) => {
					const point = Array.isArray(params) ? params[0] : null;
					if (!point) return '';
					const value = Number(point.value ?? 0);
					return `${point.axisValue}<br/>${valueFormatter(value)}`;
				}
			},
			grid: {
				top: 18,
				left: 32,
				right: 18,
				bottom: 36,
				containLabel: true
			},
			xAxis: {
				type: 'category',
				data: values.map((item) => item.label ?? item.month ?? item.year ?? '—'),
				axisLabel: {
					color: chartTheme.textColor,
					rotate: 0,
					interval: 0
				},
				axisLine: { lineStyle: { color: chartTheme.axisLineColor } }
			},
			yAxis: {
				type: 'value',
				minInterval: 1,
				axisLabel: { color: chartTheme.textColor },
				axisLine: { lineStyle: { color: chartTheme.axisLineColor } },
				splitLine: { lineStyle: { color: chartTheme.axisLineColor } }
			},
			series: [
				{
					name: chartTitle,
					data: values.map((item) => Number(item.count) || 0),
					type: 'bar',
					itemStyle: {
						color,
						borderRadius: [8, 8, 0, 0]
					},
					label: {
						show: true,
						position: 'top',
						color: chartTheme.textColor,
						formatter: '{c}'
					}
				}
			]
		};
	}

	function updateChart() {
		chart?.setOption(buildOptions(), true);
	}

	function handleResize() {
		chart?.resize();
	}

	onMount(() => {
		chart = echarts.init(chartRef);
		updateChart();
		window.addEventListener('resize', handleResize);

		return () => {
			window.removeEventListener('resize', handleResize);
			chart?.dispose();
		};
	});

	$effect(() => {
		if (chart) {
			data;
			period;
			updateChart();
		}
	});

	$effect(() => {
		if (chart && $isDarkMode !== undefined) {
			updateChart();
		}
	});
</script>

<div>
	<h5 class="text-xs font-semibold text-on-surface-variant mb-1">{title}</h5>
	<div bind:this={chartRef} class="w-full" style="height: 220px;"></div>
</div>
