<script lang="ts">
    import { onMount } from 'svelte';
    import * as echarts from 'echarts/core';
    import { BarChart, PieChart } from 'echarts/charts';
    import { GridComponent, TitleComponent, TooltipComponent, LegendComponent } from 'echarts/components';
    import { CanvasRenderer } from 'echarts/renderers';

    export let survey;
    export let users;

    echarts.use([BarChart, PieChart, GridComponent, TitleComponent, TooltipComponent, LegendComponent, CanvasRenderer]);

    let barChartRef: HTMLDivElement;
    let donutChartRef: HTMLDivElement;
    let isDarkMode = false;
    let barChart: echarts.ECharts | null = null;
    let donutChart: echarts.ECharts | null = null;

    // Prüfe Dark Mode aus html-Element
    function checkDarkMode() {
        isDarkMode = document.documentElement.classList.contains('dark');
    }

    // Farben basierend auf Theme
    $: chartTheme = {
        backgroundColor: isDarkMode ? '#1e293b' : '#ffffff',
        textColor: isDarkMode ? '#e2e8f0' : '#1e293b' ,
        axisLineColor: isDarkMode ? '#475569' : '#d1d5db',
        barColor: isDarkMode ? '#60a5fa' : '#3b82f6',
        successColor: isDarkMode ? '#34d399' : '#10b981',
        errorColor: isDarkMode ? '#f87171' : '#ef4444'
    };

    function generatePlotOptionsFromSurvey() {
        const fieldData = survey.fields?.map((field: any) => ({
            text: field.field_text,
            votes: field.feedbacks?.length || 0
        })) || [];

        return {
            title: {
                text:  'Umfrageergebnisse',
                left: 'center',
                textStyle: {
                    color: chartTheme.textColor
                }
            },
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                formatter: '{b}: {c} Stimme(n)',
                backgroundColor: isDarkMode ? '#334155' : '#ffffff',
                borderColor: chartTheme.axisLineColor,
                textStyle: {
                    color: chartTheme.textColor
                }
            },
            xAxis: {
                type: 'category',
                data: fieldData.map(field => field.text),
                axisLabel: {
                    interval: 0,
                    rotate: 30,
                    color: chartTheme.textColor
                },
                axisLine: {
                    lineStyle: {
                        color: chartTheme.axisLineColor
                    }
                }
            },
            yAxis: {
                type: 'value',
                name: 'Anzahl Stimmen',
                minInterval: 1,
                nameTextStyle: {
                    color: chartTheme.textColor
                },
                axisLabel: {
                    color: chartTheme.textColor
                },
                axisLine: {
                    lineStyle: {
                        color: chartTheme.axisLineColor
                    }
                },
                splitLine: {
                    lineStyle: {
                        color: chartTheme.axisLineColor
                    }
                }
            },
            series: [{
                name: 'Stimmen',
                type: 'bar',
                data: fieldData.map(field => field.votes),
                itemStyle: {
                    color: chartTheme.barColor,
                    borderRadius: [4, 4, 0, 0]
                },
                label: {
                    show: true,
                    position: 'top',
                    formatter: '{c}',
                    color: chartTheme.textColor
                }
            }]
        };
    }

    function generateDonutChartOptions() {
        const uniqueVoters = new Set();
        survey.fields?.forEach((field: any) => {
            field.feedbacks?.forEach((feedback: any) => {
                uniqueVoters.add(feedback.id_user);
            });
        });

        const votedCount = uniqueVoters.size;
        const totalUsers = users?.length || 0;
        const notVotedCount = totalUsers - votedCount;

        return {
            title: {
                text: 'Teilnahmeübersicht',
                left: 'center',
                textStyle: {
                    color: chartTheme.textColor
                }
            },
            tooltip: {
                trigger: 'item',
                formatter: '{b}: {c} ({d}%)',
                backgroundColor: isDarkMode ? '#334155' : '#ffffff',
                borderColor: chartTheme.axisLineColor,
                textStyle: {
                    color: chartTheme.textColor
                }
            },
            legend: {
                show: false,
                orient: 'vertical',
                left: 'left',
                data: ['Abgegeben', 'Nicht abgegeben'],
                textStyle: {
                    color: chartTheme.textColor
                }
            },
            series: [{
                name: 'Teilnahme',
                type: 'pie',
                radius: ['45%', '65%'],
                avoidLabelOverlap: false,
                padAngle: 5,
                itemStyle: {
                    borderRadius: 7
                },
                label: {
                    show: true,
                    formatter: '{b}: {d}%',
                    color: chartTheme.textColor
                },
                emphasis: {
                    label: {
                        show: true,
                        fontSize: 20,
                        fontWeight: 'bold'
                    }
                },
                data: [
                    {
                        value: votedCount,
                        name: 'Abgegeben',
                        itemStyle: { color: chartTheme.successColor }
                    },
                    {
                        value: notVotedCount,
                        name: 'Nicht abgegeben',
                        itemStyle: { color: chartTheme.errorColor }
                    }
                ]
            }]
        };
    }

    onMount(() => {
        checkDarkMode();

        barChart = echarts.init(barChartRef);
        donutChart = echarts.init(donutChartRef);

        // Initial render
        barChart.setOption(generatePlotOptionsFromSurvey());
        donutChart.setOption(generateDonutChartOptions());

        // Observer für Theme-Änderungen
        const observer = new MutationObserver(() => {
            checkDarkMode();
        });

        observer.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ['class']
        });

        return () => {
            observer.disconnect();
            barChart?.dispose();
            donutChart?.dispose();
        };
    });

    // Reaktive Updates bei Survey-Änderungen
    $: if (barChart && survey) {
        barChart.setOption(generatePlotOptionsFromSurvey());
    }

    $: if (donutChart && survey && users) {
        donutChart.setOption(generateDonutChartOptions());
    }

    // Reaktives Update bei Theme-Änderung
    $: if (barChart && donutChart && isDarkMode !== undefined) {
        barChart.setOption(generatePlotOptionsFromSurvey());
        donutChart.setOption(generateDonutChartOptions());
    }
</script>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
    <div bind:this={barChartRef} class="w-full" style="height:400px;"></div>
    <div bind:this={donutChartRef} class="w-full" style="height:400px;"></div>
</div>