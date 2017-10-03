"use strict";


$(function() {

  $('#pie_selector').change(function() {
    loadPie($(this).val())
    $('#bar_selector').val('none')
  })

  $('#bar_selector').change(function() {
    loadBar($(this).val())
    $('#pie_selector').val('none')
  })

  const loadPie = function(type) {
    $.getJSON('/api/client_specs/chart/pie/' + type).done(function(data) {

      Highcharts.chart('container', {
        chart: {
          plotBackgroundColor: null,
          plotBorderWidth: null,
          plotShadow: false,
          type: 'pie'
        },
        title: {
          text: 'Fordelingsdiagram'
        },
        tooltip: {
          pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
        },
        plotOptions: {
          pie: {
            allowPointSelect: true,
            cursor: 'pointer',
            dataLabels: {
              enabled: true,
              format: '<b>{point.name}</b>: {point.y}',
              style: {
                color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
              }
            }
          }
        },
        series: data.series
      });


    }).fail(function() {
      alert('Beklager. En feil oppsto')
    })
  }



  const loadBar = function(type) {
    $.getJSON('/api/client_specs/chart/bar/' + type).done(function(data) {
      Highcharts.chart('container', {
          chart: {
              type: 'bar'
          },
          title: {
              text: 'Klientstatus'
          },
          xAxis: {
              categories: data.categories
          },
          yAxis: {
              min: 0,
              title: {
                  text: ''
              }
          },
          legend: {
              reversed: true
          },
          plotOptions: {
              series: {
                  stacking: 'normal'
              }
          },
          series: data.series
      })
    }).fail(function() {
      alert('Beklager. En feil oppsto')
    })
  }


  $('#pie_selector option:eq(1)').prop('selected', true)
  $('#bar_selector option:eq(0)').prop('selected', true)
  loadPie( $('#pie_selector option:selected').val() )


});
