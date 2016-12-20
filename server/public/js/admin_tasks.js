"use strict";

$(function() {

  var clients, requests, admins;

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

  var save = function(form, url, type) {
    var json = {};
    var formElements = form.serializeArray();

    $.each(formElements, function() {
      json[this.name] = this.value || '';
    });

    var formData = {form_data: json};
    return $.ajax({
      url: url,
      type: type,
      data: JSON.stringify(formData),
      dataType: "json",
      contentType: "application/json; charset=UTF-8"
    });
  };


  //
  // loader functions
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


  var getAdmins = function() {
    var request = get('/api/admins/');

    request.done(function(data) {
      admins = data.admins;

      var selector = $('.admin_selector');
      selector.children().not(':first').remove();
      data.admins.forEach(admin => {
        selector.append("<option value=" + admin.id + ">" + admin.username + "</option");
      });

    });

    // viewHandler.update() ??
  };


  var getClients = function() {
    var request = get('/api/clients/');

    request.done(function(data) {
      clients = data.clients;

      var selector = $('#client_chooser');
      selector.children().remove();
      data.clients.forEach(client => {
        var classes = 'branch-' + client.branch_id
        classes += ' department-' + client.department_id
        classes += client.is_connected ? ' connected' : '';
        classes += client.shorttime ? ' shorttime' : '';
        classes += client.testclient ? ' testclient' : '';
        selector.append("<option class='clients " + classes +
        "' value='" + client.id + "'>" + client.name + "</option>");
      });

      viewHandler.update();
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
    var $branchSelector = $('.branch_selector');

    $('#branch_chooser').append('<option value=0>Alle</option>');
    data.branches.forEach(branch => {
      $branchSelector.append('<option value=' + branch.id + '>' + branch.name + '</option>');
    });

    viewHandler.setBranchFilter();
  });
};


var branchSelectors = function() {

};


var getDepartments = function() {
  var request = get('/api/departments/');

  request.done(function(data) {
    var $departmentSelector = $('.department_selector');
    $('#department_chooser').append('<option value=0>Alle</option>');
    data.departments.forEach(department => {
      $departmentSelector.append('<option class="departments branch-' +
      department.branch_id + '" value=' + department.id + '>' + department.name + '</option>');
    });
  });
};


//
// Handler object to juggle the various views for the client editor form.
//
var viewHandler = {
  clientFilter: '',
  branchFilter: '',
  departmentFilter: '',
  preferredClientID: null,

  setClientFilter: function() {
    var category = $('#filter_selector').val();
    var chosenValue = $("input[name='client_filter']:radio:checked").val();
    var includeCategory = chosenValue === 'on' ? true : false;

    if (category === '') {
      this.clientFilter = '';
    } else {
      this.clientFilter = includeCategory ? category : ':not(' + category + ')';
    }

    this.preferredClientID = $('#client_chooser').val();
  },

  setDepartmentFilter: function() {
    var departmentID = $('#department_chooser').val();
    this.departmentFilter = departmentID === '0' ? '' : '.department-' + departmentID;
  },

  setBranchFilter: function() {
    var branchID = $('#branch_chooser').val();
    this.branchFilter = branchID === '0' ? '' : '.branch-' + branchID;
  },

  update: function() {
    // determine visible departments
    var $departmentChooser = $('#department_chooser');
    $departmentChooser.find('.departments').not(':first').hide();
    $departmentChooser.find('.departments' + this.branchFilter).show();

    // determine visible clients
    var $clientChooser = $('#client_chooser');
    $clientChooser.find('.clients').hide();
    $clientChooser.find('.clients' + this.clientFilter + this.departmentFilter + this.branchFilter).show();

    var clientID = $clientChooser.find(':visible').first().val();

    // retain the previously selected client if visible
    if (this.preferredClientID) {
      var $preferredClient = $clientChooser.find('option[value="' + this.preferredClientID + '"]');
      if ($preferredClient.is(':visible')) {
        clientID = $preferredClient.val();
      }

      this.preferredClientID = null;
    }

    $('#client_chooser').val(clientID);
    $clientChooser.change();
  },

  reloadClients: function() {
    this.preferredClientID = $('#client_chooser').val();
    getClients();
  },

  init: function() {
    getClients();
    getBranches();
    getDepartments();
    getRequests();
    getAdmins();
    $('.branch_selector.in_form').change();
    $('#filter_selector').val(1);
    $("input[name='client_view']:radio").first().prop('checked', true);
    //$('#save_new_client').prop('disabled', false);
  }
};


//
// event handlers
//

$("#branch_chooser").change(function() {
  viewHandler.setBranchFilter();
  viewHandler.update();
});


$('.branch_selector.in_form').change(function() {
  var branchID = $(this).val();
  var $form = $(this).parent();

  $form.find('.departments').hide();
  $form.find('.branch-' + branchID).show();
  $form.find('.department_selector .branch-' + branchID).first().prop('selected', true);
});



$("#department_chooser").change(function() {
  viewHandler.setDepartmentFilter();
  viewHandler.update();
});


$("#client_chooser").change(function() {
  var clientID = $(this).val();
  var $form = $("#edit_client_form");

  clients.forEach(client => {
    if (client.id === parseInt(clientID)) {
      var date = new Date(client.ts);
      var dateString = date.getHours() + ':' + date.getMinutes() + ' ' + date.getDate() +
       "-" + (date.getMonth() +1 )+ "-" + date.getFullYear();
      $form.find('#ts').val(dateString);

      $form.find('.branch_selector').val(client.branch_id).change();

      populate($form, client);
    }
  });
});



$("#request_selector").change(function() {
  var requestID = $(this).val();
  var $form = $("#add_client_form");

  clear($form);
  $('#delete_request').prop('disabled', (requestID === '0'));

  requests.forEach(request => {
    if (request.id === parseInt(requestID)) {
      populate($form, request);
    }
  });
});


var foo = function(data, itemID, $form) {
  clear($form);
  //$('#delete_request').prop('disabled', (requestID === '0'));

  data.forEach(item => {
    if (item.id === parseInt(itemID)) {
      populate($form, item);
    }
  });
}


$(".admin_selector").change(function() {
  var adminID = $(this).val();
  var $form = $("#admin_form");
  foo(admins, adminID, $form);
});




$("input[name='client_filter']:radio").change(function () {
  viewHandler.setClientFilter();
  viewHandler.update();
});


$('#filter_selector').change(function() {
  viewHandler.setClientFilter();
  viewHandler.update();
});


// minor convenience function to quickly suggest ip for new clients (not terribly robust)
$('#suggest_ip').click(function() {
  var selectedBranchID = parseInt($('#add_client_form').find('.branch_selector.in_form').val());
  var highest = 0;
  var network = '';

  clients.forEach(client => {
    if (client.branch_id === selectedBranchID) {
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


$('#show_password').mousedown(function() {
  $('#password').replaceWith($('#password').clone().prop('type', 'text'));
});

$('#show_password').mouseup(function() {
  $('#password').replaceWith($('#password').clone().prop('type', 'password'));
});


// ** options tabs handling **
$('.taskpane').hide();
$('.taskpane:first').addClass('active').show();

$('.tasktabs li').click(function() {
  $('.tasktabs li.active').removeClass('active');
  $(this).addClass('active');
  $('.taskpane').hide();
  $('.taskpane:eq(' + $(this).index() + ')').show();
});




//
// CRUD functions
//

$('#save_client_changes').click(function() {
  var form = $('#edit_client_form');
  var request = save(form, '/api/clients/', 'PUT');


  request.done(function(message) {
    var msg = "OK. Endringene ble lagret.";
    $('span#client_info').html(msg).show().fadeOut(5000);

    viewHandler.reloadClients();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $('span#client_error').html(jqXHR.responseText).show().fadeOut(5000);
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
      viewHandler.reloadClients();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#client_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  }
});



$('#save_new_client').click(function() {
  var form = $('#add_client_form');
  var request = save(form, '/api/clients/', 'POST');

  request.done(function(message) {
    var msg = "OK. Endringene ble lagret.";
    $('span#request_info').html(msg).show().fadeOut(5000);
    getRequests();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $('span#request_error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


// admins

$('#save_admin').click(function() {
  var form = $('#admin_form');
  var request = save(form, '/api/admins/', 'POST');

  request.done(function(message) {
    var msg = "OK. Endringene ble lagret.";
    $('span#admin_info').html(msg).show().fadeOut(5000);
    getAdmins();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $('span#admin_error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


$('#delete_admin').click(function() {
  var adminID = $('#admin_form').find("input[name='id']").val();
  var adminName = $('#admin_form').find("input[name='username']").val();

  if (window.confirm('Sikker på at du vil slette ' + adminName + '?')) {
    var request = $.ajax({
      url: '/api/admins/' + adminID,
      type: 'DELETE',
    });

    request.done(function(message) {
      var msg = "OK. Slettet.";
      $('span#admin_info').html(msg).show().fadeOut(5000);
      viewHandler.reloadClients();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#admin_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  }
  return false;
});






// requests

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
viewHandler.init();

});
