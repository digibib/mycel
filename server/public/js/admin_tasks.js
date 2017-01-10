"use strict";

$(function() {
  let clients, branches, departments, requests, admins;
  let clientOptions, branchOptions, departmentOptions, requestOptions, adminOptions;

  //
  // form helper functions
  // $('select')
  const clear = function($form) {
    $form.find(':input').not(':button, :submit, :reset, :checkbox, :radio, select').val('');
    $form.find(':checkbox, :radio').prop('checked', false);
    $form.find('select').first().prop('selected', true);
  };

  const populate = function($form, data) {
    clear($form);

    $.each(data, function(name, val){
      const $formElement = $form.find('[name="' + name + '"]');
      const type = $formElement.prop('type');

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

  const findAndPopulate = function($form, items, itemID) {
    const item = items.find(item => item.id == itemID);
    populate($form, item);
  };

  // filters options to populate dropdown box
  const populateSelector = function($selector, $options, filterString, retainFirst) {
    const preferredID = $selector.val();

    retainFirst ? $selector.children().not(':first').remove() : $selector.children().remove();
    const $clonedOptions = $options.map(option => option.clone());
    $selector.append($clonedOptions.filter($option => $option.filter(filterString).length));

    if (preferredID && $selector.find('option[value=' + preferredID + ']').length) {
      $selector.val(preferredID);
    } else {
      $selector.first().prop('selected', true);
    }
  };

  const save = function(form, url, type) {
    const json = {};
    const formElements = form.serializeArray();

    $.each(formElements, function() {
      json[this.name] = this.value || '';
    });

    const formData = {form_data: json};
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
  const get = function(url) {
    return $.ajax({
      url: url,
      type: 'GET',
      dataType: 'json',
      contentType: 'application/json; charset=UTF-8',
      cache: false
    });
  };

  const getAdmins = function(selectedID) {
    return get('/api/admins/').done(function(data) {
      admins = data.admins;
      const $selector = $('.admin_selector').empty();

      adminOptions = [];
      adminOptions.push($('<option />', {'text': 'Ny admin', 'value': '0'}));

      data.admins.forEach(admin => {
        adminOptions.push($('<option />', {
          'text': admin.username,
          'value': admin.id,
          'data-type': admin.owner_admins_type, // needed?
          'data-id': admin.owner_admins_id // needed?
        }));
      });

      $selector.append(adminOptions);

      if (selectedID) {
        $selector.val(selectedID);
      }
    });
  };


  const getClients = function(selectedID) {
    return get('/api/clients/').done(function(data) {
      clients = data.clients;
      const $selector = $('#client_selector').empty();

      clientOptions = [];
      data.clients.forEach(client => {
        let classString = 'clients'
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

      $selector.append(clientOptions);
      if (selectedID) {
        $selector.val(selectedID);
      }
    }
  );
};


const getRequests = function(selectedID) {
  return get('/api/requests/').done(function(data) {
    requests = data.requests;
    const $selector = $('#request_selector').empty();

    requestOptions = [];
    requestOptions.push($('<option />', {'text': 'Ny klient', 'value': '0'}));
    data.requests.forEach(request => {
      const date = new Date(request.ts);
      const dateString = '(' + date.getDate() + "-" + (date.getMonth() +1) + "-" + date.getFullYear() + ')';

      requestOptions.push($('<option />', {
        'text': request.hostname + ' (' + dateString + ')',
        'value': request.id
      }));
    });

    $selector.append(requestOptions);
    if (selectedID) {
      $selector.val(selectedID);
    }
  });
};


const getBranches = function(selectedID) {
  return get('/api/branches/').done(function(data) {
    branches = data.branches;
    const $branchSelector = $('.branch_selector').empty();
    $('#branch_selector').append($('<option />', {'text': 'Alle', 'value': '0'}));

    branchOptions = [];
    data.branches.forEach(branch => {
      branchOptions.push($('<option />', {'text': branch.name, 'value': branch.id}));
    });

    $branchSelector.append(branchOptions);
    if (selectedID) {
      $branchSelector.val(selectedID);
    }
  });
};



const getDepartments = function(selectedID) {
  return get('/api/departments/').done(function(data) {
    departments = data.departments;
    departmentOptions = [];

    const $departmentSelector = $('.department_selector').empty();
    $('#department_selector').append('<option value=0>Alle</option>');

    data.departments.forEach(department => {
      departmentOptions.push($('<option />', {
        'text': department.name,
        'value': department.id,
        'class': 'departments branch-' + department.branch_id,
        'data-branch_id': department.branch_id // needed?
      }));
    });

    $departmentSelector.append(departmentOptions);
    if (selectedID) {
      $departmentSelector.val(selectedID);
    }
  });
};

//
// Universal event handlers
//
$('.branch_selector.in_form').change(function() {
  const branchID = $(this).val();
  const $form = $(this).parent();

  const filter = '.departments.branch-' + branchID;
  const $department_selector = $form.find('.department_selector');
  populateSelector($department_selector, departmentOptions, filter, false);
});

//
// Handler object to juggle the various views for the client editor forms.
//
const ViewHandler = {
  $branchSelector: $('#branch_selector'),
  $departmentSelector: $('#department_selector'),
  $clientSelector: $('#client_selector'),
  $categoryFilterSelector: $('#category_filter_selector'),
  $categorySwitch: $("input[name='category_switch']:radio"),
  $editClientForm: $('#edit_client_form'),
  $requestSelector: $('#request_selector'),
  $addClientForm: $("#add_client_form"),
  $saveChangesButton: $('#save_client_changes'),
  $deleteClientButton: $('#delete_client'),
  $saveNewButton: $('#save_new_client'),
  $deleteRequestButton: $('#delete_request'),
  clientFilter: '',
  branchFilter: '',
  departmentFilter: '',

  init: function() {
    this.bindUIActions();
    this.$categoryFilterSelector.children().first().prop('selected', true);
    this.$categorySwitch.first().prop('checked', true);
    this.refresh();
    clear(this.$addClientForm);
  },
  bindUIActions: function() {
    const self = this;

    this.$branchSelector.change(function() {
      self.setBranchFilter().refresh();
    });

    this.$departmentSelector.change(function() {
      self.setDepartmentFilter().refresh();
    });

    this.$clientSelector.change(function() {
      self.refresh();
    });

    this.$categorySwitch.change(function () {
      self.setClientFilter().refresh();
    });

    this.$categoryFilterSelector.change(function() {
      self.setClientFilter().refresh();
    });

    this.$requestSelector.change(function() {
      const requestID = parseInt($(this).val());
      // $('#delete_request').prop('disabled', (requestID === 0));

      if (requestID === 0) {
        clear(self.$addClientForm);
      } else {
        const request = requests.find(request => request.id === requestID);
        populate(self.$addClientForm, request);
      }
    });

    this.$saveChangesButton.click(function() {
      if (self.$clientSelector.children().length) {
        const request = save(self.$editClientForm, '/api/clients/', 'POST');

        request.done(function(data) {
          self.$editClientForm.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadClients();
        });

        request.fail(function(jqXHR, textStatus, errorThrown) {
          self.$editClientForm.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });


    this.$deleteClientButton.click(function() {
      const clientID = $('#client_id').val();
      const clientName = self.$editClientForm.find('#edit_client_name').val();

      if (clientName && window.confirm('Sikker på at du vil slette ' + clientName + '?')) {
        const request = $.ajax({
          url: '/api/clients/' + clientID,
          type: 'DELETE',
        });

        request.done(function(data) {
          $form.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadClients();
        });

        request.fail(function(jqXHR, textStatus, errorThrown) {
          $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });

    this.$saveNewButton.click(function() {
      // SPECIAL: set request id
      self.$addClientForm.find('[name=request_id]').val($('#request_id').val());
      $('#request_id').val('');

      // post client
      const request = save($form, '/api/clients/', 'POST');

      request.done(function(data) {
        self.$addClientForm.find('span.info').html(data.message).show().fadeOut(5000);
        clear(self.$addClientForm);
        getRequests();
        self.reloadClients();
      });

      request.fail(function(jqXHR, textStatus, errorThrown) {
        self.$addClientForm.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    });

    this.$deleteRequestButton.click(function() {
      const $form = self.$addClientForm;
      const requestID = $('#request_id').val();
      const requestName = self.$requestSelector.children().filter(':selected').text();

      if (requestName && window.confirm('Sikker på at du vil slette ' + requestName + '?')) {
        const request = $.ajax({
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
      }
    });
  },

  setClientFilter: function() {
    const categoryFilter = this.$categoryFilterSelector.val();
    const includeCategory = this.$categorySwitch.filter(':checked').val() === 'on';

    if (categoryFilter === '') {
      this.clientFilter = '';
    } else {
      this.clientFilter = includeCategory ? categoryFilter : ':not(' + categoryFilter + ')';
    }
    return this;
  },

  setDepartmentFilter: function() {
    const departmentID = this.$departmentSelector.val();
    this.departmentFilter = departmentID === '0' ? '' : '.department-' + departmentID;
    return this;
  },

  setBranchFilter: function() {
    const branchID = this.$branchSelector.val();
    this.branchFilter = branchID === '0' ? '' : '.branch-' + branchID;
    return this;
  },

  refresh: function() {
    // determine visible departments
    populateSelector(this.$departmentSelector, departmentOptions, '.departments' + this.branchFilter, true);
    this.setDepartmentFilter();

    // determine visible clients
    const clientFilter = '.clients' + this.clientFilter + this.departmentFilter + this.branchFilter;
    populateSelector(this.$clientSelector, clientOptions, clientFilter, false);

    // adjust in-form department selector and populate form
    const client = clients.find(client => client.id === parseInt(this.$clientSelector.val()));

    if (client) {
      const branchID = client.branch_id;
      const filter = '.departments.branch-' + branchID;
      const selector = this.$editClientForm.find('.department_selector.in_form');
      populateSelector(selector, departmentOptions, filter, false);

      populate(this.$editClientForm, client);
    } else {
      clear(this.$editClientForm);
    }
  },

  reloadClients: function() {
    const self = this;
    const selectedID = this.$clientSelector.val();

    $.when(getClients(selectedID))
    .then(function() {
      self.refresh()
    });
  }
};

//
// ADMINS
//
const AdminHandler = {
  type: '',
  $form: $('#admin_form'),
  $adminDepartments: $('#admin_departments'),
  $adminBranches: $('#admin_branches'),
  $ownerAdminsType: $("input[name='owner_admins_type']:radio"),

  init: function() {
    this.bindUIActions();
    this.resetForm();
  },
  bindUIActions: function() {
    const self = this;

    $("#admin_selector").change(function() {
      const adminID = $(this).val();

      if (adminID === '0') {
        self.resetForm();
      } else {
        findAndPopulate(self.$form, admins, adminID);
        const ownerID = $('#owner_admins_id').val();
        self.set_admins_type(self.$form.find("input[name='owner_admins_type']:checked").val());


        if (self.type === 'Department') {
          // infer branch from department ID
          const dept = departmentOptions.find(option => option.val() == aid);
          const branchID = dept.data('branch_id');
          self.$adminDepartments.val(ownerID);
          self.$adminBranches.val(branchID);
        } else {
          // ownerID same as branchID
          self.$adminBranches.val(ownerID);
        }

        self.refresh();
      }
    });

    $("input[name='owner_admins_type']:radio").change(function () {
      self.set_admins_type($(this).val()).refresh();
    });

  },

  set_admins_type: function(type) {
    this.type = type;
    return this;
  },

  resetForm: function() {
    clear(this.$form);
    this.$ownerAdminsType.val(['Branch']);
    this.set_admins_type('Branch');
    this.refresh();
    return this;
  },
  // move this
  reloadAdmins: function() {
    //this.preferredAdminID = $('.admin_selector').val();
    getAdmins(); // -------------------------------> fix me
  },
  refresh: function() {
    if (this.type === 'Department') {
      const did = this.$adminDepartments.val();
      const filter = '.departments.branch-' + this.$adminBranches.val();
      populateSelector(this.$adminDepartments, departmentOptions, filter, false);
      this.$adminDepartments.show();
      this.$adminBranches.show();
    } else if (this.type === 'Branch') {
      this.$adminDepartments.hide();
      this.$adminBranches.show();
    } else {
      this.$adminDepartments.hide();
      this.$adminBranches.hide();
    }
  }
};


const toggle_admins_typez = function() {
  const $adminDepts = $('#admin_departments');
  const type = $("input[name='owner_admins_type']:checked").val();

  if (type === 'Department') {
    const did = $(this).find(':selected').val();
    const admins_id = $(this).find(':selected').data('id');

    //var branchID = $('#admin_branches').val();
    const filter = '.departments.branch-' + $('#admin_branches').val();
    populateSelector($adminDepts, departmentOptions, filter, false);
    $adminDepts.show();
  } else {
    $adminDepts.hide();
  }
};

// admins

$('#save_admin').click(function() {
  const $form = $('#admin_form');
  const request = save($form, '/api/admins/', 'POST');

  request.done(function(data) {
    $form.find('span.info').html(data.message).show().fadeOut(5000);
    getAdmins(data.id);
  });

  request.fail(function(jqXHR, textStatus, errorThrown) {
    $form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
  });
});


$('#delete_admin').click(function() {
  const $form = $('#admin_form');
  const adminID = $form.find("input[name='id']").val();
  const adminName = $form.find("input[name='username']").val();

  if (window.confirm('Sikker på at du vil slette ' + adminName + '?')) {
    const request = $.ajax({
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


//
// Affiliates
//
const affiliateHandler = {
  init: function() {
    this.bindUIActions();
    $('input:radio[name="affiliate_type"][value="Branch"]').prop('checked', true).change();
  },
  bindUIActions: function() {
    const self = this;

    $("input[name='affiliate_type']:radio").change(function () {
      self.setType($(this).val());
    });

    this.$branchSelector.change(function() {
      self.setBranch($(this).val());
    });

    this.$departmentSelector.change(function() {
      self.setDepartment($(this).val());
    });
  },
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
    const filter = '.departments' + (branchID === '0' ? '' : '.branch-' + branchID);
    populateSelector(this.$departmentSelector, departmentOptions, filter, true);
    //this.$departmentSelector.prepend(this.$newOption);
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
      const deptID = this.$departmentSelector.val();
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

$('#save_affiliate').click(function() {
  const $form = affiliateHandler.$form;

  if (affiliateHandler.type === 'Branch') {
    $('#organization_id').val('1'); // iffy thing
    const func = getBranches;
    const apiString = '/api/branches/';
  } else {
    $('#affiliate_branch_id').val($('#affiliate_branches').val());
    const func = getDepartments;
    const apiString = '/api/departments/';
  }

  const request = save($form, apiString, 'POST');

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
  const $form = affiliateHandler.$form;

  // prepare parameters
  if (affiliateHandler.type === 'Branch') {
    const func = getBranches;
    const id = $('#affiliate_branches').val();
    const apiString = '/api/branches/' + id;
  } else {
    const func = getDepartments;
    const id = $('#affiliate_departments').val();
    apiString = '/api/departments/' + id;
  }

  // if no affiliate is set, we return
  if (id == '0') {
    return;
  }

  // all set
  const request = $.ajax({
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





// minor convenience function to quickly suggest ip for new clients (not terribly robust)
$('#suggest_ip').click(function() {
  const selectedBranchID = parseInt($('#add_client_form').find('.branch_selector.in_form').val());
  let highest = 0;
  let network = '';

  clients.forEach(client => {
    if (client.branch_id === selectedBranchID) {
      const ip = client.ipaddr;
      const index = ip.lastIndexOf('.') + 1;

      if (ip.split('.').length === 4) {
        network = ip.substring(0, index);
      }
      const address = parseInt(ip.substring(index));
      highest = address > highest ? address : highest;
    }
  });

  const suggestedIP = network + (highest +1);
  $('#add_client_form').find('#ipaddr').val(suggestedIP);
});


// change to class!? ------------------------------------
$('#show_password').mousedown(function() {
  $('#password').replaceWith($('#password').clone().prop('type', 'text'));
});

$('#show_password').mouseup(function() {
  $('#password').replaceWith($('#password').clone().prop('type', 'password'));
});







//
// CRUD functions
//



// profiles
$('#delete_profile').click(function() {
  const $form = $('#profile_form');
  const msg = "Implementeres på forespørsel";
  $form.find('span.info').html(msg).show().fadeOut(5000);
});

$('#save_profile').click(function() {
  const $form = $('#profile_form');
  const msg = "Implementeres på forespørsel";
  $form.find('span.info').html(msg).show().fadeOut(5000);
});

//
// Initialize page
//

// admin tasks tabs handling
$('.taskpane').hide();
$('.taskpane:first').addClass('active').show();

$('.tasktabs li').click(function() {
  $('.tasktabs li.active').removeClass('active');
  $(this).addClass('active');
  $('.taskpane').hide();
  $('.taskpane:eq(' + $(this).index() + ')').show();
});

// load and initialize
$.when(
  getClients(), getBranches(), getDepartments(), getRequests(), getAdmins()
).then(function() {
  console.log("all done!!");
  ViewHandler.init();
  affiliateHandler.init();
  AdminHandler.init();
});

});
