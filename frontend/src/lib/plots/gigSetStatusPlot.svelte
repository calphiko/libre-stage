<!--
  libre-stage - Band rehearsal and gig management software
  Copyright (C) 2026  libre-stage contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

<script lang="ts">
    import { onMount, tick } from 'svelte';
    import * as echarts from 'echarts/core';
    import { BarChart } from 'echarts/charts';
    import { GridComponent, TooltipComponent, LegendComponent, DataZoomComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';
    import { isDarkMode } from '$lib/themeStore';

    /** Array of set objects from GigStatistics, each with set_name and songs[] */
    let { sets = [], titlePrefix = 'Songs je Set' } = $props();

    echarts.use([BarChart, GridComponent, TooltipComponent, LegendComponent, DataZoomComponent, CanvasRenderer]);

    let chartRef: HTMLDivElement;
    let chart: echarts.ECharts | null = null;

    let chartTheme = $derived({
        textColor: $isDarkMode ? '#e2e8f0' : '#1e293b',
        axisLineColor: $isDarkMode ? '#475569' : '#d1d5db',
        tooltipBackground: $isDarkMode ? '#334155' : '#ffffff',
        playedColor: '#3b82f6',
        insertedColor: '#10b981',
        skippedColor: '#f59e0b',
    });

    let setCount = $derived((sets ?? []).length);
    let hasManyBars = $derived(setCount > 12);
    let isCompact = $derived(setCount > 0 && setCount <= 8);
    let compactWidthPx = $derived(Math.max(460, Math.min(940, 220 + setCount * 92)));

    function buildOptions() {
        const setNames: string[] = [];
        const playedData: number[] = [];
        const insertedData: number[] = [];
        const skippedData: number[] = [];

        for (const set of sets ?? []) {
            setNames.push(set.set_name ?? 'Set');
            let played = 0, inserted = 0, skipped = 0;
            for (const song of set.songs ?? []) {
                if (song.uebersprungen) skipped++;
                else if (song.eingeschoben) inserted++;
                else played++;
            }
            playedData.push(played);
            insertedData.push(inserted);
            skippedData.push(-skipped);   // negativ → unterhalb der X-Achse
        }

        return {
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                backgroundColor: chartTheme.tooltipBackground,
                borderColor: chartTheme.axisLineColor,
                textStyle: { color: chartTheme.textColor },
                formatter: (params: any[]) => {
                    const name = params[0]?.name ?? '';
                    const lines = params
                        .filter((p) => p.value !== 0)
                        .map((p) => `${p.marker}${p.seriesName}: <b>${Math.abs(p.value)}</b>`)
                        .join('<br/>');
                    return `<b>${name}</b><br/>${lines || '–'}`;
                }
            },
            legend: {
                top: 0,
                textStyle: { color: chartTheme.textColor }
            },
            grid: {
                top: 38,
                left: 34,
                right: 14,
                bottom: hasManyBars ? 52 : 28,
                containLabel: true
            },
            xAxis: {
                type: 'category',
                data: setNames,
                axisLabel: {
                    color: chartTheme.textColor,
                    interval: 0,
                    rotate: setCount > 4 ? 35 : 0,
                    hideOverlap: true,
                    width: 72,
                    overflow: 'truncate',
                    lineHeight: 12,
                    fontSize: 10
                },
                axisLine: { lineStyle: { color: chartTheme.axisLineColor } }
            },
            yAxis: {
                type: 'value',
                minInterval: 1,
                axisLabel: {
                    color: chartTheme.textColor,
                    formatter: (value: number) => `${Math.abs(value)}`
                },
                axisLine: { lineStyle: { color: chartTheme.axisLineColor } },
                splitLine: { lineStyle: { color: chartTheme.axisLineColor } }
            },
            series: [
                {
                    name: 'Gespielt',
                    type: 'bar',
                    stack: 'positive',
                    barMaxWidth: 26,
                    barMinHeight: 1,
                    itemStyle: { color: chartTheme.playedColor },
                    data: playedData
                },
                {
                    name: 'Eingeschoben',
                    type: 'bar',
                    stack: 'positive',
                    barMaxWidth: 26,
                    barMinHeight: 1,
                    itemStyle: { color: chartTheme.insertedColor },
                    data: insertedData
                },
                {
                    name: 'Übersprungen',
                    type: 'bar',
                    stack: 'negative',
                    barMaxWidth: 26,
                    barMinHeight: 1,
                    itemStyle: { color: chartTheme.skippedColor },
                    data: skippedData
                }
            ],
            barCategoryGap: hasManyBars ? '30%' : '44%',
            dataZoom: hasManyBars ? [
                { type: 'inside', xAxisIndex: 0, startValue: 0, endValue: 9 },
                { type: 'slider', xAxisIndex: 0, height: 14, bottom: 4, startValue: 0, endValue: 9 }
            ] : []
        };
    }

    function updateChart() {
        chart?.setOption(buildOptions(), true);
    }

    function handleResize() {
        chart?.resize();
    }

    onMount(async () => {
        await tick();
        chart = echarts.init(chartRef);
        updateChart();
        setTimeout(() => chart?.resize(), 50);
        window.addEventListener('resize', handleResize);

        return () => {
            window.removeEventListener('resize', handleResize);
            chart?.dispose();
        };
    });

    $effect(() => {
        if (chart) { sets; updateChart(); }
    });

    $effect(() => {
        if (chart && $isDarkMode !== undefined) updateChart();
    });
</script>

<div>
    <h5 class="text-xs font-semibold text-on-surface-variant mb-1">{titlePrefix}</h5>
    <div class="w-full">
        <div
            bind:this={chartRef}
            class={isCompact ? 'mx-auto' : 'w-full'}
            style="height: 260px; width: {isCompact ? `${compactWidthPx}px` : '100%'}; max-width: 100%;"
        ></div>
    </div>
</div>

