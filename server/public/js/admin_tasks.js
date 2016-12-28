"use strict";

$(function() {

  var clients, branches, departments, requests, admins;
  var clientOptions, branchOptions, departmentOptions, requestOptions, adminOptions;

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



  var foo = function(data, itemID, $form) {
    clear($form);
    //$('#delete_request').prop('disabled', (requestID === '0'));

    data.forEach(item => {
      if (item.id === parseInt(itemID)) {
        populate($form, item);
      }
    });
  }



  // populates dropdown box according to filter
  var filterSelector = function($selector, $options, filterString, retainFirst) {
    var preferredID = $selector.val();

    retainFirst ? $selector.children().not(':first').remove() : $selector.children().remove();
    $selector.append($options.filter(option => option.filter(filterString).length > 0));

    $selector.val(preferredID);
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


  var getAdmins = function(selectedID) {
    var selector = $('.admin_selector');

    return get('/api/admins/').done(function(data) {
      admins = data.admins;
      selector.children().not(':first').remove();

      data.admins.forEach(admin => {
        selector.append("<option value=" + admin.id + ">" + admin.username + "</option");
      });

      if (selectedID) {
        selector.val(selectedID).change();
      }
    });
  };


  var getClients = function() {
    var request = get('/api/clients/');

    return request.done(function(data) {
      clients = data.clients;

      var selector = $('#client_chooser');
      var preferredID = selector.val();

      clientOptions = [];
      data.clients.forEach(client => {
        var classString = 'clients'
          + ' branch-' + client.branch_id
          + ' department-' + client.department_id
          + (client.is_connected ? ' connected' : '')
          + (client.shorttime ? ' shorttime' : '')
          + (client.testclient ? ' testclient' : '');

        clientOptions.push($('<option />', {
          'text': client.name,
          'value': client.id,
          'class': classString
        }));
      });

      selector.children().remove();
      selector.append(clientOptions);

      if (preferredID) {
        selector.val(preferredID);
      }
    }
  );
};


var getRequests = function() {
  var request = get('/api/requests/');

  return request.done(function(data) {
    requests = data.requests;

    var selector = $('#request_selector');
    selector.children().remove();
    selector.append('<option value="0">Ny klient</option>');
    requestOptions = [];
    data.requests.forEach(request => {
      var date = new Date(request.ts);
      var dateString = '(' + date.getDate() + "-" + (date.getMonth() +1) + "-" + date.getFullYear() + ')';

      requestOptions.push($('<option />', {
        'text': request.name + ' (' + dateString + ')',
        'value': request.id
      }));
    });

    selector.append(requestOptions);

    selector.change(); // hmmm
  });
};


var getBranches = function() {
  var request = get('/api/branches/');

  return request.done(function(data) {
    var $branchSelector = $('.branch_selector');

    $('#branch_chooser').append('<option value=0>Alle</option>');
    data.branches.forEach(branch => {
      $branchSelector.append('<option value=' + branch.id + '>' + branch.name + '</option>');
    });

    viewHandler.setBranchFilter();
  });
};



var getDepartments = function() {
  var request = get('/api/departments/');

  return request.done(function(data) {
    departmentOptions = [];

    var $departmentSelector = $('.department_selector');
    $departmentSelector.children().remove();

    $('#department_chooser').append('<option value=0>Alle</option>');

    data.departments.forEach(department => {
      departmentOptions.push($('<option />', {
        'text': department.name,
        'value': department.id,
        'class': 'departments branch-' + department.branch_id
      }));
    });

    $departmentSelector.append(departmentOptions);
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
  preferredAdminID: null, // remove

  setClientFilter: function() {
    var category = $('#filter_selector').val();
    var chosenValue = $("input[name='client_filter']:radio:checked").val();
    var includeCategory = chosenValue === 'on';

    if (category === '') {
      this.clientFilter = '';
    } else {
      this.clientFilter = includeCategory ? category : ':not(' + category + ')';
    }
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
    var preferredDepartmentID = $departmentChooser.val();
    filterSelector($departmentChooser, departmentOptions, '.departments' + this.branchFilter, true);

    // determine visible clients
    var $clientChooser = $('#client_chooser');
    var preferredClientID = $clientChooser.val();
    var classFilter = '.clients' + this.clientFilter + this.departmentFilter + this.branchFilter;

    $clientChooser.children().remove();
    $clientChooser.append(clientOptions.filter(option => option.filter(classFilter).length > 0));
    $clientChooser.val(preferredClientID);

    // populate client info
    var foo = clients.filter(client => client.id === parseInt($clientChooser.val()))[0];
    var $form = $("#edit_client_form");
    populate($form, foo);
  },

  reloadClients: function() {
    //this.preferredClientID = $('#client_chooser').val();
    getClients();
  },

  // move this
  reloadAdmins: function() {
    this.preferredAdminID = $('.admin_selector').val();
    getAdmins();
  },

  init: function() {
    $.when(
      getClients(), getBranches(), getDepartments(), getRequests(), getAdmins()
    ).then(function() {
      console.log("all done!");
      $('.branch_selector.in_form').change();
      $('#filter_selector').val(1);
      $("input[name='client_view']:radio").first().prop('checked', true);
      //$('#save_new_client').prop('disabled', false);
    });
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
  var $form = $(this).parent(); // hmmm

  //$form.find('.departments').hide();
  //$form.find('.branch-' + branchID).show();
  //$form.find('.department_selector .branch-' + branchID).first().prop('selected', true);

  var filter = '.departments.branch-' + branchID;
  var selector = $form.find('.department_selector');
  filterSelector(selector, departmentOptions, filter, false);

    //var preferredDepartmentID = foo.val();
    //foo.children().not(':first').remove();
    //foo.append(departmentOptions.filter(option => option.filter('.departments .branch-' + branchID).length > 0));
    //foo.val(preferredDepartmentID);
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
      $form.find('.branch_selector').val(client.branch_id).change(); // hmmmm

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
    $('span#admin_info').html(message.message).show().fadeOut(5000);
    getAdmins(message.id);
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
      $('span#admin_info').html(message.message).show().fadeOut(5000);
      getAdmins(false);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#admin_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  }
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
