"use strict";

$(function() {

  var clients, branches, departments, requests, admins;
  var clientOptions, branchOptions, departmentOptions, requestOptions, adminOptions;

  //
  // form helper functions
  //
  var clear = function($form) {
    $form.find(':input').not(':button, :submit, :reset, :checkbox, :radio').val('');
    $form.find(':checkbox, :radio').prop('checked', false);
  };

  var populate = function($form, data) {
    clear($form);

    $.each(data, function(name, val){
      var $formElement = $form.find('[name="' + name + '"]');
      var type = $formElement.prop('type');

      switch(type){
        case 'checkbox':
        $formElement.prop('checked', val);
        break;
        case 'radio':
        $formElement.filter('[value="' + val + '"]').prop('checked', 'checked');
        break;
        default:
        $formElement.val(val);
      }
    });
  };

  var findAndPopulate = function($form, data, itemID) {
    var item = data.find(item => item.id == itemID);
    populate($form, item);
  };

  // populates dropdown box according to filter
  var filterSelector = function($selector, $options, filterString, retainFirst) {
    var preferredID = $selector.val();

    retainFirst ? $selector.children().not(':first').remove() : $selector.children().remove();
    var clonedOptions = $options.map(option => option.clone());
    $selector.append(clonedOptions.filter(option => option.filter(filterString).length > 0));

    $selector.val(preferredID);
  };

  var save = function(form, url, type) {
    var json = {};
    var formElements = form.serializeArray();

    $.each(formElements, function() {
      json[this.name] = this.value || '';
    });

    var formData = {form_data: json};
    console.log(formData);
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
        selector.append($('<option />', {
          'text': admin.username,
          'value': admin.id,
          'data-type': admin.owner_admins_type,
          'data-id': admin.owner_admins_id
        }));
      });

      if (selectedID) {
        selector.val(selectedID);
      }
    });
  };


  var getClients = function(selectedID) {
    var request = get('/api/clients/');

    return request.done(function(data) {
      clients = data.clients;

      var selector = $('#client_selector');
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


var getRequests = function(selectedID) {
  var request = get('/api/requests/');

  return request.done(function(data) {
    requests = data.requests;

    var selector = $('#request_selector');
    selector.children().remove();
    selector.append('<option value="">Ny klient</option>');
    requestOptions = [];
    data.requests.forEach(request => {
      var date = new Date(request.ts);
      var dateString = '(' + date.getDate() + "-" + (date.getMonth() +1) + "-" + date.getFullYear() + ')';

      requestOptions.push($('<option />', {
        'text': request.hostname + ' (' + dateString + ')',
        'value': request.id
      }));
    });

    selector.append(requestOptions);
    if (selectedID) {
      selector.val(selectedID);
    }

    selector.change(); // hmmm
  });
};


var getBranches = function(selectedID) {
  var request = get('/api/branches/');

  return request.done(function(data) {
    branches = data.branches;
    var $branchSelector = $('.branch_selector');
    $branchSelector.children().remove();

    $('#branch_selector').append('<option value=0>Alle</option>');
    data.branches.forEach(branch => {
      $branchSelector.append($('<option />', {'text': branch.name, 'value': branch.id}));
    });

    if (selectedID) {
      $branchSelector.val(selectedID);
    }

    viewHandler.setBranchFilter(); // why?
  });
};



var getDepartments = function(selectedID) {
  var request = get('/api/departments/');

  return request.done(function(data) {
    departments = data.departments;
    departmentOptions = [];

    var $departmentSelector = $('.department_selector');
    $departmentSelector.children().remove();

    $('#department_selector').append('<option value=0>Alle</option>');

    data.departments.forEach(department => {
      departmentOptions.push($('<option />', {
        'text': department.name,
        'value': department.id,
        'class': 'departments branch-' + department.branch_id,
        'data-branch_id': department.branch_id
      }));
    });

    $departmentSelector.append(departmentOptions);
    if (selectedID) {
      $departmentSelector.val(selectedID);
    }
  });
};


//
// Handler object to juggle the various views for the client editor form.
//
var viewHandler = {
  clientFilter: '',
  branchFilter: '',
  departmentFilter: '',
  preferredClientID: null, // remove?
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
    var departmentID = $('#department_selector').val();
    this.departmentFilter = departmentID === '0' ? '' : '.department-' + departmentID;
  },

  setBranchFilter: function() {
    var branchID = $('#branch_selector').val();
    this.branchFilter = branchID === '0' ? '' : '.branch-' + branchID;
  },

  update: function() {
    // determine visible departments
    var $departmentSelector = $('#department_selector');
    filterSelector($departmentSelector, departmentOptions, '.departments' + this.branchFilter, true);
    this.setDepartmentFilter();

    // determine visible clients
    var $clientSelector = $('#client_selector');
    var clientFilter = '.clients' + this.clientFilter + this.departmentFilter + this.branchFilter;
    filterSelector($clientSelector, clientOptions, clientFilter, false);

    // populate client info...
    var client = clients.filter(client => client.id === parseInt($clientSelector.val()))[0];
    var $form = $("#edit_client_form");

    // adjust in-form department selector...
    var branchID = client.branch_id;
    var filter = '.departments.branch-' + branchID;
    var selector = $form.find('.department_selector.in_form');
    filterSelector(selector, departmentOptions, filter, false);

    populate($form, client);
  },

  reloadClients: function() {
    var self = this;

    $.when(getClients())
    .then(function() {
      self.update()});
  },

  // move this
  reloadAdmins: function() {
    this.preferredAdminID = $('.admin_selector').val();
    getAdmins();
  },

  init: function() {
    var self = this;
    return $.when(
      getClients(), getBranches(), getDepartments(), getRequests(), getAdmins()
    ).then(function() {
      $('#filter_selector').val(1);
      $("input[name='client_view']:radio").first().prop('checked', true);
      //$('#save_new_client').prop('disabled', false);
      self.update();
      //$("#request_selector").change();
    });
  }
};


//
// event handlers
//

$("#branch_selector").change(function() {
  viewHandler.setBranchFilter();
  viewHandler.update();
});

$("#department_selector").change(function() {
  viewHandler.setDepartmentFilter();
  viewHandler.update();
});

$("#client_selector").change(function() {
  viewHandler.update();
});

$('.branch_selector.in_form').change(function() {
  var branchID = $(this).val();
  var $form = $(this).parent();

  var filter = '.departments.branch-' + branchID;
  var selector = $form.find('.department_selector');
  filterSelector(selector, departmentOptions, filter, false);
});

// rewrite foreach to filter
$("#request_selector").change(function() {
  var requestID = $(this).val();
  var $form = $("#add_client_form");

  $('#delete_request').prop('disabled', (requestID === ''));

  if (requestID === '') {
    clear($form);
  } else {
    requests.forEach(request => {
      if (request.id === parseInt(requestID)) {
        populate($form, request);
      }
    });
  }
});

var toggle_admins_type = function() {
  var $adminDepts = $('#admin_departments');
  var type = $("input[name='owner_admins_type']:checked").val();

  if (type === 'Department') {
    var did = $(this).find(':selected').val();
    var admins_id = $(this).find(':selected').data('id');

    //var branchID = $('#admin_branches').val();
    var filter = '.departments.branch-' + $('#admin_branches').val();
    filterSelector($adminDepts, departmentOptions, filter, false);
    $adminDepts.show();
  } else {
    $adminDepts.hide();
  }
};


$(".admin_selector").change(function() {
  var adminID = $(this).val();

  var $form = $("#admin_form");
  findAndPopulate($form, admins, adminID);

  var aid = $('#owner_admins_id').val();
  var type = $form.find("input[name='owner_admins_type']:checked").val();

  if (type === 'Department') {
    var dept = departmentOptions.find(option => option.val() == aid);
    $('#admin_departments').val(aid).show();
    $('#admin_branches').val(dept.data('branch_id'));
  } else {
    $('#admin_departments').hide();
    $('#admin_branches').val(aid);
  }
  //toggle_admins_type();
});


$("input[name='client_filter']:radio").change(function () {
  viewHandler.setClientFilter();
  viewHandler.update();
});


$('#filter_selector').change(function() {
  viewHandler.setClientFilter();
  viewHandler.update();
});


var affiliateHandler = {
  $newOption: $('<option />', {
    'text': 'Ny',
    'value': '0'
  }),
  type: 'Branch',
  $branchSelector: $('#affiliate_branches'),
  $departmentSelector: $('#affiliate_departments'),
  $form: $('#affiliate_form'),
  setType: function(type) {
    this.type = type;
    if (type === 'Department') {
      this.filterDepartments(this.$branchSelector.val());
      this.$departmentSelector.prepend(this.$newOption).show();
      this.setDepartment(this.$departmentSelector.val());
    } else {
      this.setBranch(this.$branchSelector.val());
      this.$branchSelector.prepend(this.$newOption);
      this.$departmentSelector.hide();
    }
  },
  filterDepartments: function(branchID) {
    var filter = '.departments' + (branchID === '0' ? '' : '.branch-' + branchID);
    filterSelector(this.$departmentSelector, departmentOptions, filter, false);
    this.$departmentSelector.prepend(this.$newOption);
  },
  setDepartment: function(departmentID) {
    if (departmentID === '0') {
      clear(this.$form);
    } else {
      findAndPopulate(this.$form, departments, departmentID);
    }
  },
  setBranch: function(branchID) {
    if (this.type === 'Branch') {
      branchID == '0' ? clear(this.$form) : findAndPopulate(this.$form, branches, branchID);
    } else {
      this.filterDepartments(branchID);
      var deptID = this.$departmentSelector.val();
      if (deptID == '0') {
        clear(this.$form);
      } else {
        this.setDepartment(deptID);
      }
    }
  },
  refresh: function() {
    if (this.type === 'Branch') {
      this.setBranch(this.$branchSelector.val());
    } else {
      this.filterDepartments(this.$branchSelector.val());
      this.setDepartment(this.$departmentSelector.val());
    }
  }
};


$("input[name='affiliate_type']:radio").change(function () {
  affiliateHandler.setType($(this).val());
});

$('#affiliate_branches').change(function() {
  affiliateHandler.setBranch($(this).val());
});

$('#affiliate_departments').change(function() {
  affiliateHandler.setDepartment($(this).val());
});

$("input[name='owner_admins_type']:radio").change(function () {
    toggle_admins_type();
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


// admin tasks tabs handling
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
  var $form = $('#edit_client_form');
  var request = save($form, '/api/clients/', 'POST');

  request.done(function(data) {
    $form.find('span.info').html(data.message).show().fadeOut(5000);
    viewHandler.reloadClients();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


$('#delete_client').click(function() {
  var $form = $('#edit_client_form');
  var clientID = $('#client_id').val();
  var clientName = $form.find('#edit_client_name').val();

  if (window.confirm('Sikker på at du vil slette ' + clientName + '?')) {
    var request = $.ajax({
      url: '/api/clients/' + clientID,
      type: 'DELETE',
    });

    request.done(function(data) {
      $form.find('span.info').html(data.message).show().fadeOut(5000);
      viewHandler.reloadClients();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  }
});



$('#save_new_client').click(function() {
  var $form = $('#add_client_form');

  // set request id
  $form.find('[name=request_id]').val($('#request_id').val());
  $('#request_id').val('');
  var request = save($form, '/api/clients/', 'POST');

  request.done(function(data) {
    $form.find('span.info').html(data.message).show().fadeOut(5000);
    clear($form);
    getRequests();
    viewHandler.reloadClients();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


// admins

$('#save_admin').click(function() {
  var $form = $('#admin_form');
  var request = save($form, '/api/admins/', 'POST');

  request.done(function(data) {
    $form.find('span.info').html(data.message).show().fadeOut(5000);
    getAdmins(data.id);
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


$('#delete_admin').click(function() {
  var $form = $('#admin_form');
  var adminID = $form.find("input[name='id']").val();
  var adminName = $form.find("input[name='username']").val();

  if (window.confirm('Sikker på at du vil slette ' + adminName + '?')) {
    var request = $.ajax({
      url: '/api/admins/' + adminID,
      type: 'DELETE',
    });

    request.done(function(data) {
      clear($form);
      $form.find('span.info').html(data.message).show().fadeOut(5000);
      getAdmins(false);
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  }
});


// requests

$('#delete_request').click(function() {
  var $form = $('#admin_form');
  var requestID = $('#request_id').val();

  var request = $.ajax({
    url: '/api/requests/' + requestID,
    type: 'DELETE'
  });

  request.done(function(data) {
    $form.find('span.info').html(data.message).show().fadeOut(5000);
    getRequests();
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


// affiliates

$('#save_affiliate').click(function() {
  var $form = affiliateHandler.$form;

  if (affiliateHandler.type === 'Branch') {
    $('#organization_id').val('1');
    var func = getBranches;
    var apiString = '/api/branches/';
  } else {
    $('#affiliate_branch_id').val($('#affiliate_branches').val());
    var func = getDepartments;
    var apiString = '/api/departments/';
  }

  var request = save($form, apiString, 'POST');

  request.done(function(data) {
    $form.find('span.info').html(data.message).show().fadeOut(5000);
    $.when(func(data.id)).then(function() {
      affiliateHandler.refresh();
    });
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


$('#delete_affiliate').click(function() {
  var $form = affiliateHandler.$form;

  // prepare parameters
  if (affiliateHandler.type === 'Branch') {
    var func = getBranches;
    var id = $('#affiliate_branches').val();
    var apiString = '/api/branches/' + id;
  } else {
    var func = getDepartments;
    var id = $('#affiliate_departments').val();
    apiString = '/api/departments/' + id;
  }

  // ignore command for undefined affiliate
  if (id == '0') {
    return;
  }

  // all set
  var request = $.ajax({
    url: apiString,
    type: 'DELETE'
  });

  request.done(function(data) {
    $form.find('span.info').html(data.message).show().fadeOut(5000);
    $.when(func()).then(function() {
        affiliateHandler.refresh();
    }
  );
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


// profiles
$('#delete_profile').click(function() {
  var $form = $('#profile_form');
  var msg = "Implementeres på forespørsel";
  $form.find('span.info').html(msg).show().fadeOut(5000);
});

$('#save_profile').click(function() {
  var $form = $('#profile_form');
  var msg = "Implementeres på forespørsel";
  $form.find('span.info').html(msg).show().fadeOut(5000);
});

//
// Initialize page
//
$.when(viewHandler.init()).then(function() {
  console.log("all done!!");
  $('input:radio[name="affiliate_type"][value="Branch"]').prop('checked', true).change();
  //affiliateHandler.setType('Branch');
});
//viewHandler.init();

//$("#request_selector").change();

});
