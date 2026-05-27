<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { PieChart } from 'echarts/charts';
    import { TooltipComponent, GraphicComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    let {
        playedGigCount = 0,
        gigCount = 0,
        titlePrefix = 'Gigs gespielt'
    } = $props();

    echarts.use([PieChart, TooltipComponent, GraphicComponent, CanvasRenderer]);

    let chartRef: HTMLDivElement;
    let chart: echarts.ECharts | null = null;

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff',
        playedColor: '#3b82f6',
        openColor: $isDarkMode ? '#334155' : '#e2e8f0'
    });

    function toInt(value: unknown) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed)) return 0;
        return Math.max(0, Math.round(parsed));
    }

    function buildOptions() {
        const played = toInt(playedGigCount);
        const total = Math.max(toInt(gigCount), played);
        const open = Math.max(0, total - played);

        if (total === 0) {
            return {
                graphic: {
                    type: 'text',
                    left: 'center',
                    top: 'middle',
                    style: {
                        text: 'Keine Gigs vorhanden',
                        fill: chartTheme.textColor,
                        fontSize: 12
                    }
                }
            };
        }

        const percent = Math.round((played / total) * 100);

        return {
            tooltip: {
                trigger: 'item',
                formatter: '{b}: {c}',
                backgroundColor: chartTheme.tooltipBackground,
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor }
            },
            series: [{
                name: titlePrefix,
                type: 'pie',
                radius: ['56%', '78%'],
                avoidLabelOverlap: true,
                label: { show: false },
                labelLine: { show: false },
                itemStyle: { borderRadius: 7 },
                data: [
                    { value: played, name: 'Gespielt', itemStyle: { color: chartTheme.playedColor } },
                    { value: open, name: 'Offen', itemStyle: { color: chartTheme.openColor } }
                ]
            }],
            graphic: [
                {
                    type: 'text',
                    left: 'center',
                    top: '43%',
                    style: {
                        text: `${played}/${total}`,
                        fill: chartTheme.textColor,
                        fontSize: 22,
                        fontWeight: 700,
                        textAlign: 'center'
                    }
                },
                {
                    type: 'text',
                    left: 'center',
                    top: '58%',
                    style: {
                        text: `${percent}%`,
                        fill: chartTheme.textColor,
                        fontSize: 12,
                        textAlign: 'center'
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
            playedGigCount;
            gigCount;
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
    <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}</h5>
    <div bind:this={chartRef} class="w-full h-[190px] sm:h-[210px] md:h-[220px]"></div>
</div>

