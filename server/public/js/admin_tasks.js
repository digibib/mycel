"use strict";

$(function() {

  var clients, requests;
  var clientFilter = '';
  var preferredClient = null;

  //
  // form helper functions
  //
  var clear = function(form) {
    form.find(':input').not(':button, :submit, :reset, :checkbox, :radio').val('');
    form.find(':checkbox, :radio').prop('checked', false);
  };

  var populate = function(form, data) {
    $.each(data, function(name, val){
      var formElement = form.find('[name="' + name + '"]');
      var type = formElement.prop('type');

      switch(type){
        case 'checkbox':
        formElement.prop('checked', val);
        break;
        case 'radio':
        formElement.filter('[value="'+val+'"]').prop('checked', 'checked');
        break;
        default:
        formElement.val(val);
      }
    });
  };

  var save = function(form, type) {
    var json = {};
    var formElements = form.serializeArray();

    $.each(formElements, function() {
      json[this.name] = this.value || '';
    });

    var formData = {form_data: json};
    return $.ajax({
      url: '/api/clients/',
      type: type,
      data: JSON.stringify(formData),
      dataType: "json",
      contentType: "application/json; charset=UTF-8"
    });
  };


  //
  // loader unctions
  //
  var get = function(url) {
    return $.ajax({
      url: url,
      type: 'GET',
      dataType: 'json',
      contentType: 'application/json; charset=UTF-8',
      cache: false
    });
  };


  var getClients = function() {
    var request = get('/api/clients/');

    request.done(function(data) {
      clients = data.clients;

      var selector = $('.client_selector');
      selector.children().remove();
      data.clients.forEach(client => {
        var connected = client.is_connected ? ' on' : ' off';
        selector.append("<option class='clients branch-" + client.branch_id + connected +
        "' value='" + client.id + "'>" + client.name + "</option>");
      });

      $('.branch_selector.edit').change();
    }
  );
};


var getRequests = function() {
  var request = get('/api/requests/');

  request.done(function(data) {
    requests = data.requests;

    var selector = $('#request_selector');
    selector.children().remove();
    selector.append('<option value="0">Ny klient</option>');
    data.requests.forEach(request => {
      var date = new Date(request.ts);
      var dateString = '(' + date.getDate() + "-" + (date.getMonth() +1 )+ "-" + date.getFullYear() + ')';
      selector.append('<option value=' + request.id + '>id: ' + request.id + dateString + '</option>');
    });

    selector.change();
  });
};


var getBranches = function() {
  var request = get('/api/branches/');

  request.done(function(data) {
    data.branches.forEach(branch => {
      $('.branch_selector').append('<option value=' + branch.id + '>' + branch.name + '</option>');
    });
  });
};


var getDepartments = function() {
  var request = get('/api/departments/');

  request.done(function(data) {
    data.departments.forEach(department => {
      $(".department_selector").append('<option class="departments branch-' +
      department.branch_id + '" value=' + department.id + '>' + department.name + '</option>');
    });
  });
};

//
// event handlers
//
$(".branch_selector.edit").change(function() {
  var branchID = $(this).val();
  var clientSelector = $('.client_selector');

  if (preferredClient) {
    clientSelector.find('option[value="' + preferredClient + '"]').addClass('preferred');
    preferredClient = null;
  }

  clientSelector.find('.clients').hide();
  clientSelector.find(clientFilter + '.branch-' + branchID).show();

  // on reload, prefer the currently selected client if visible
  if (clientSelector.find('.preferred:visible').size() === 1) {
    clientSelector.find('.preferred').removeClass('preferred').prop('selected', true);
  } else {
    clientSelector.find(':visible').first().prop('selected', true);
    clientSelector.find('.preferred').removeClass('preferred');
  }

  clientSelector.change();
});


$('.branch_selector.in_form').change(function() {
  var branchID = $(this).val();
  var form = $(this).parent();

  form.find('.departments').hide();
  form.find('.branch-' + branchID).show();
  form.find('.department_selector .branch-' + branchID).first().prop('selected', true);
});


$(".client_selector").change(function() {
  var clientID = $(this).val();
  var form = $("#edit_client_form");

  clients.forEach(client => {
    if (client.id === parseInt(clientID)) {
      form.find('.branch_selector').val(client.branch_id).change();
      populate(form, client);
    }
  });
});


$("#request_selector").change(function() {
  var requestID = $(this).val();
  var form = $("#add_client_form");

  clear(form);
  $('#delete_request').prop('disabled', (requestID === '0'));

  requests.forEach(request => {
    if (request.id === parseInt(requestID)) {
      populate(form, request);
    }
  });
});


$("input[name='client_view']:radio").change(function () {
  var type = $(this).val();
  clientFilter = type === 'all' ? '' : type;

  preferredClient = $('.client_selector').val();
  $(".branch_selector.edit").change();
});


// minor convenience function to quickly add ip for new clients
// not terribly robust
$('#suggest_ip').click(function() {
  var selectedBranchID = $('#add_client_form').find('.branch_selector').val();
  var highest = 0;
  var network = '';

  clients.forEach(client => {
    if (client.branch_id === parseInt(selectedBranchID)) {
      var ip = client.ipaddr;
      var index = ip.lastIndexOf('.') + 1;

      if (ip.split('.').length === 4) {
        network = ip.substring(0, index);
      }
      var address = parseInt(ip.substring(index));
      highest = address > highest ? address : highest;
    }
  });

  var suggestedIP = network + (highest +1);
  $('#add_client_form').find('#ipaddr').val(suggestedIP);
});



//
// CRUD functions
//
$('#save_client_changes').click(function() {
  var form = $('#edit_client_form');
  var request = save(form, 'PUT');


  request.done(function(message) {
    var msg = "OK. Endringene ble lagret.";
    $('span#client_info').html(msg).show().fadeOut(5000);

    preferredClient = $('.client_selector').val();
    getClients();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $('span#client_error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


$('#save_new_client').click(function() {
  var form = $('#add_client_form');
  var request = save(form, 'POST');

  request.done(function(message) {
    var msg = "OK. Endringene ble lagret.";
    $('span#request_info').html(msg).show().fadeOut(5000);
    getRequests();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $('span#request_error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


$('#delete_client').click(function() {
  var clientID = $('#client_id').val();
  var clientName = $('#edit_client_form').find('name').val();

  if (window.confirm('Sikker på at du vil slette ' + clientName + '?')) {
    var request = $.ajax({
      url: '/api/clients/' + clientID,
      type: 'DELETE',
    });

    request.done(function(message) {
      var msg = "OK. Slettet.";
      $('span#client_info').html(msg).show().fadeOut(5000);
      getClients();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#client_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  }
});


$('#delete_request').click(function() {
  var requestID = $('#request_id').val();

  var request = $.ajax({
    url: '/api/requests/' + requestID,
    type: 'DELETE'
  });

  request.done(function() {
    var msg = "OK. Slettet.";
    $('span#request_info').html(msg).show().fadeOut(5000);
    getRequests();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $('span#request_error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});

//
// Initialize page
//
getClients();
getBranches();
getDepartments();
getRequests();
$("input[name='client_view']:radio").first().prop('checked', true);

});
