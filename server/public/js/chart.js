"use strict";


$(function() {

  $('#pie_selector').change(function() {
    loadPie($(this).val())
  })

  const loadPie = function(type) {
    $.getJSON('/api/client_specs/' + type).done(function(data) {

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
              format: '<b>{point.name}</b>: {point.percentage:.1f} %',
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


  loadPie( $('#pie_selector option:selected').val() )
  //const foo = window.location.search.substring(1)
  //let params = foo.split('&');
  //params.forEach(function(param) {
  //param.split('=')
  //})

});
