"use strict";
/* global $ */

$(function() {
  let clients, branches, departments, requests, admins, printers;
  let clientOptions, branchOptions, departmentOptions, requestOptions, adminOptions, printerOptions;

  //
  // form helper functions
  //
  const clear = function($form) {
    $form.find(':input').not(':button, :submit, :reset, :checkbox, :radio, select').val('');
    $form.find(':checkbox, :radio').prop('checked', false);
    $form.find('select').first().prop('selected', true);
  };

  const populate = function($form, data) {
    clear($form);

    $.each(data, function(name, val) {
      const $formElement = $form.find('[name="' + name + '"]');
      const type = $formElement.prop('type');

      switch (type) {
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
      adminOptions.push($('<option />', {text: 'Ny admin', value: '0'}));

      data.admins.forEach(admin => {
        adminOptions.push($('<option />', {
          text: admin.username,
          value: admin.id
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
        let classString = 'clients' +
        ' branch-' + client.branch_id +
        ' department-' + client.department_id +
        (client.is_connected ? ' connected' : '') +
        (client.shorttime ? ' shorttime' : '') +
        (client.testclient ? ' testclient' : '');

        clientOptions.push($('<option />', {
          text: client.name,
          value: client.id,
          class: classString
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
      requestOptions.push($('<option />', {text: 'Ny klient', value: '0'}));
      data.requests.forEach(request => {
        const date = new Date(request.ts);
        const dateString = '(' + date.getDate() + "-" + (date.getMonth() + 1) +
        "-" + date.getFullYear() + ')';

        requestOptions.push($('<option />', {
          text: request.id + ' ' + request.hostname + ' (' + dateString + ')',
          value: request.id
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
      $('#branch_selector').append($('<option />', {text: 'Alle', value: '0'}));

      branchOptions = [];
      data.branches.forEach(branch => {
        branchOptions.push($('<option />', {
          text: branch.name,
          value: branch.id,
          'data-default-printer': branch.options.default_printer_id
            || branch.options_inherited.default_printer_id
         }));
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
          text: department.name,
          value: department.id,
          'data-default-printer': department.options.default_printer_id
            || department.options_inherited.default_printer_id,
          'data-printer-is-inherited': !department.options.default_printer_id,
          class: 'departments branch-' + department.branch_id
        }));
      });

      $departmentSelector.append(departmentOptions);
      if (selectedID) {
        $departmentSelector.val(selectedID);
      }
    });
  };

  const getProfiles = function(selectedID) {
    return get('/api/profiles/').done(function(data) {
      const $profileSelector = $('#profile_selector').empty();
      const options = [];
      options.push($('<option />', {text: 'Ny profil', value: '0'}));

      data.profiles.forEach(profile => {
        options.push($('<option />', {
          'text': profile.name,
          'value': profile.id,
          'data-profile': JSON.stringify(profile)
        }));
      });

      $profileSelector.append(options);
      if (selectedID) {
        $profileSelector.val(selectedID);
      }
    });
  };


  const getPrinterProfiles = function(selectedID) {
    return get('/api/printer_profiles/').done(function(data) {
      const $profileSelector = $('.printer_profile_selector').empty();
      const options = [];
      // options.push($('<option />', {text: 'Ny printerprofil', value: '0'}));
      $('#printer_profile_selector').append($('<option />', {text: 'Ny printerprofil', value: '0'}));

      data.printer_profiles.forEach(profile => {
        options.push($('<option />', {
          'text': profile.name,
          'value': profile.id,
          'data-printer_profile': JSON.stringify(profile)
        }));
      });

      $profileSelector.append(options);
      if (selectedID) {
        $profileSelector.val(selectedID);
      }
    });
  };

  // printer_selector
  const getPrinters = function(selectedID) {
    return get('/api/printers/').done(function(data) {
      const $printerSelector = $('.printer_selector').empty();
      $('#printer_selector').append($('<option />', {text: 'Ny printer', value: '0'}));
      printerOptions = [];
      //options.push($('<option />', {text: 'Ny printer', value: '0'}));

      data.printers.forEach(printer => {
        printerOptions.push($('<option />', {
          'text': printer.name,
          'value': printer.id,
          'class': 'printers branch-' + printer.branch_id,
          'data-printer': JSON.stringify(printer), // dont use this i dont think
          'data-name': printer.name,
          'data-id': printer.id
        }));
      });

      $printerSelector.append(printerOptions);
      if (selectedID) {
        $printerSelector.val(selectedID);
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
    const $departmentSelector = $form.find('.department_selector');
    populateSelector($departmentSelector, departmentOptions, filter, false);
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

    this.$categorySwitch.change(function() {
      self.setClientFilter().refresh();
    });

    this.$categoryFilterSelector.change(function() {
      self.setClientFilter().refresh();
    });

    this.$requestSelector.change(function() {
      const requestID = parseInt($(this).val(), 10);

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
          type: 'DELETE'
        });

        request.done(function(data) {
          self.$editClientForm.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadClients();
        });

        request.fail(function(jqXHR, textStatus, errorThrown) {
          $$editClientForm.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });

    this.$saveNewButton.click(function() {
      // SPECIAL: set request id
      self.$addClientForm.find('[name=request_id]').val($('#request_id').val());
      $('#request_id').val('');

      // post client
      const request = save(self.$addClientForm, '/api/clients/', 'POST');

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
      console.log("hmmph: " + requestID);
      if (requestID && window.confirm('Sikker på at du vil slette ' + requestName + '?')) {
        const request = $.ajax({
          url: '/api/requests/' + requestID,
          type: 'DELETE'
        });

        request.done(function(data) {
          $form.find('span.info').html(data.message).show().fadeOut(5000);
          getRequests(); // -----------> FIX ME?!  ------------------<
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
    const client = clients.find(client => client.id === parseInt(this.$clientSelector.val(), 10));

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
      self.refresh();
    });
  }
};

//
// ADMINS
//
const AdminHandler = {
  type: '',
  $form: $('#admin_form'),
  get $adminsTypeSwitch() {return this.$form.find("input[name='owner_admins_type']:radio");},
  $adminSelector: $('#admin_selector'),
  $adminDepartments: $('#admin_departments'),
  $adminBranches: $('#admin_branches'),
  $saveAdminButton: $('#save_admin'),
  $deleteAdminButton: $('#delete_admin'),
  init: function() {
    this.bindUIActions();
    this.resetForm();
  },
  bindUIActions: function() {
    const self = this;

    this.$adminsTypeSwitch.change(function() {
      self.setAdminsType($(this).val()).refresh();
    });

    this.$adminSelector.change(function() {
      const adminID = $(this).val();

      if (adminID === '0') {
        self.resetForm();
      } else {
        findAndPopulate(self.$form, admins, adminID);
        const ownerID = $('#owner_admins_id').val();
        self.setAdminsType(self.$adminsTypeSwitch.filter(':checked').val());

        if (self.type === 'Department') {
          // infer branch from department ID
          const dept = departments.find(option => option.id == ownerID);
          const branchID = dept.branch_id;
          self.$adminDepartments.val(ownerID);
          self.$adminBranches.val(branchID);
        } else {
          // ownerID same as branchID
          self.$adminBranches.val(ownerID);
        }

        self.refresh();
      }
    });

    this.$saveAdminButton.click(function() {
      // SPECIAL: set correct owner_admins_id based on type
      const adminTypes = {
        Branch: self.$adminBranches.val(),
        Department: self.$adminDepartments.val(),
        Organization: '1'
      };

      const ownerAdminsID = adminTypes[self.type];
      $('#owner_admins_id').val(ownerAdminsID);

      // save form
      const request = save(self.$form, '/api/admins/', 'POST');

      request.done(function(data) {
        self.$form.find('span.info').html(data.message).show().fadeOut(5000);
        self.reloadAdmins(data.id); // hmm, blir ikke oppdatert skikkelig - alle feltene blir ikke fylt ut
      });

      request.fail(function(jqXHR, textStatus, errorThrown) {
        self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    });

    this.$deleteAdminButton.click(function() {
      const adminID = self.$form.find("input[name='id']").val();
      const adminName = self.$form.find("input[name='username']").val();

      if (adminID && window.confirm('Sikker på at du vil slette ' + adminName + '?')) {
        const request = $.ajax({
          url: '/api/admins/' + adminID,
          type: 'DELETE'
        });

        request.done(function(data) {
          clear(self.$form);
          self.$form.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadAdmins(false); // hmm, admintypteswitch blir ikke resatt
        });

        request.fail(function(jqXHR, textStatus, errorThrown) {
          self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
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
          const address = parseInt(ip.substring(index), 10);
          highest = address > highest ? address : highest;
        }
      });

      const suggestedIP = network + (highest + 1);
      $('#add_client_form').find('#ipaddr').val(suggestedIP);
    });

    $('#show_password').mousedown(function() {
      $('#password').replaceWith($('#password').clone().prop('type', 'text'));
    });

    $('#show_password').mouseup(function() {
      $('#password').replaceWith($('#password').clone().prop('type', 'password'));
    });
  },

  setAdminsType: function(type) {
    this.type = type;
    return this;
  },

  resetForm: function() {
    clear(this.$form);
    this.$adminsTypeSwitch.val(['Branch']);
    this.setAdminsType('Branch').refresh();
    return this;
  },

  reloadAdmins: function(id) {
    $.when(getAdmins(id))
    .then(function() {
      this.$adminSelector.change();
    }.bind(this));
  },
  refresh: function() {
    if (this.type === 'Department') {
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

//
// Affiliates
//
const AffiliateHandler = {
  type: 'Branch',
  $branchSelector: $('#affiliate_branches'),
  $departmentSelector: $('#affiliate_departments'),
  $printerSelector: $('#affiliate_printers'),
  $form: $('#affiliate_form'),
  $typeSwitch: $('input:radio[name="affiliate_type"]'),
  $newOption: $('<option />', {
    text: 'Ny',
    value: '0'
  }),
  init: function() {
    this.bindUIActions();
    this.resetForm();
  },
  bindUIActions: function() {
    const self = this;

    this.$typeSwitch.change(function() {
      self.setType($(this).val());
    });

    this.$branchSelector.change(function() {
      self.setBranch($(this).val());
    });

    this.$departmentSelector.change(function() {
      self.setDepartment($(this).val());
    });

    $('#affiliate_printers').change(function() {
      // if type == Branch ==> branchSelector.data-default-printer is set?
    })

    $('#save_affiliate, #set_default_printer').click(function() {
      // prepare refresh functions
      let id, reloadFunc, apiString;

      if (self.type === 'Branch') {
        $('#organization_id').val('1'); // iffy thing
        apiString = '/api/branches/';
        id = $('#affiliate_branches').val();
        reloadFunc = function() {
          $.when(getBranches(id)).then(function() {
            self.setBranch(id);
          });
        };
      } else {
        id = $('#affiliate_departments').val();
        $('#affiliate_branch_id').val($('#affiliate_branches').val());
        apiString = '/api/departments/';
        reloadFunc = function() {
          $.when(getDepartments(id)).then(function() {
            self.setBranch($('#affiliate_branches').val());
            self.setDepartment(id);
          });
        };
      }

      // save form or set printer
      let request;
      if ($(this).attr('id') == "save_affiliate") {
        request = save(self.$form, apiString, 'POST');
      } else {
        request = $.ajax({
                url: apiString + id,
                type: 'PUT',
                data: JSON.stringify({default_printer_id: self.$printerSelector.find(':selected').val()}),
                dataType: "json",
                contentType: "application/json; charset=UTF-8"
              })
      }

      request.done(function(data) {
          self.$form.find('span.error').hide();
          self.$form.find('span.info').html(data.message).show().fadeOut(5000);
          reloadFunc();
      });

      request.fail(function(jqXHR, textStatus, errorThrown) {
          self.$form.find('span.info').hide();
          self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        })
    });

    $('#delete_affiliate').click(function() {
      let reloadFunc, id, apiString;

      // prepare parameters
      if (self.type === 'Branch') {
        reloadFunc = getBranches;
        id = $('#affiliate_branches').val();
        apiString = '/api/branches/' + id;
      } else {
        reloadFunc = getDepartments;
        id = $('#affiliate_departments').val();
        apiString = '/api/departments/' + id;
      }

      if (id != '0' && window.confirm('Sikker på at du vil slette ' + $('#affiliate_name').val() + '?')) {
        const request = $.ajax({
          url: apiString,
          type: 'DELETE'
        });

        request.done(function(data) {
          self.$form.find('span.info').html(data.message).show().fadeOut(5000);
          $.when(reloadFunc()).then(function() {
            self.resetForm();
          });
        });

        request.fail(function(jqXHR, textStatus, errorThrown) {
          self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });
  },
  setType: function(type) {
    this.type = type;
    if (type === 'Department') {
      this.$departmentSelector.prepend(this.$newOption).show();
      this.setDepartment(this.$departmentSelector.val());
    } else {
      this.$branchSelector.prepend(this.$newOption);
      this.$departmentSelector.hide();
      this.setBranch(this.$branchSelector.val());
    }
    return this;
  },
  filterDepartments: function(branchID) {
    let filter = '.departments' + (branchID === '0' ? '' : '.branch-' + branchID);
    populateSelector(this.$departmentSelector, departmentOptions, filter, false);
    filter = '.printers' + (branchID === '0' ? '' : '.branch-' + branchID);
    populateSelector(this.$printerSelector, printerOptions, filter, false);
    return this;
  },
  setDepartment: function(departmentID) {
    if (departmentID === '0') {
      clear(this.$form);
    } else {
      this.$departmentSelector.val(departmentID);
      findAndPopulate(this.$form, departments, departmentID);
      //this.$printerSelector.val(this.$departmentSelector.find(':selected').data('default-printer'));
      this.setPrinter(this.$departmentSelector);
    }
    return this;
  },
  setBranch: function(branchID) {
    this.filterDepartments(branchID);

    if (this.type === 'Branch') {
      this.$branchSelector.prepend(this.$newOption);
      this.$branchSelector.val(branchID);
      branchID == '0' ? clear(this.$form) : findAndPopulate(this.$form, branches, branchID);

      //this.$printerSelector.val(this.$branchSelector.find(':selected').data('default-printer'));
      this.setPrinter(this.$branchSelector);
    } else {
      this.$departmentSelector.prepend(this.$newOption);
      this.$departmentSelector.children().first().prop('selected', true);
      clear(this.$form);
      //this.$printerSelector.val(this.$departmentSelector.find(':selected').data('default-printer'));
      this.setPrinter(this.$departmentSelector);
    }

    return this;
  },
  setPrinter: function(sel) {
    let defaultPrinterID = sel.find(':selected').data('default-printer');
    let isInherited = sel.find(':selected').data('printer-is-inherited');

    this.$printerSelector.find('option').each (function(i) {
      $(this).text($(this).data('name')); // reset printer name

      if ($(this).val() == defaultPrinterID) {
        let append = isInherited ? '* (arvet)' : '*'
        $(this).text($(this).text() + append);
      }
    })

    this.$printerSelector.val(defaultPrinterID);
  },
  resetForm: function() {
    clear(this.$form);
    this.$typeSwitch.filter('[value="Branch"]').prop('checked', true).change();
  }
};

//
// PROFILES
//
const ProfileHandler = {
  $profileSelector: $('#profile_selector'),
  $form: $('#profile_form'),
  init: function() {
    this.bindUIActions();
    this.showProfile('0');
  },
  reloadProfiles: function(id) {
    $.when(getProfiles(id))
    .then(function() {
      this.showProfile(id);
    }.bind(this));
  },
  showProfile: function(profileID) {
    if (profileID == '0') {
      clear(this.$form);
    } else {
      populate(this.$form, this.$profileSelector.children().filter(':selected').data('profile'));
    }
  },
  bindUIActions: function() {
    const self = this;

    this.$profileSelector.change(function() {
      self.showProfile($(this).val());
    });

    $('#save_profile').click(function() {
      save(self.$form, '/api/profiles/', 'POST')
      .done(function(data) {
        self.$form.find('span.info').html(data.message).show().fadeOut(5000);
        self.reloadProfiles(data.id);
      })
      .fail(function(jqXHR, textStatus, errorThrown) {
        self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    });

    $('#clone_profile').click(function() {
      const profileID = self.$profileSelector.val();
      if (profileID != '0') {
        self.showProfile(self.$profileSelector.val());
        self.$form.find('[name="name"]').val("klone");
        self.$form.find('[name="id"]').val("0");
      }
    });

    $('#delete_profile').click(function() {
      const profileID = self.$profileSelector.val();
      const profileName = self.$form.find('[name="name"]').val();

      if (profileID != '0' && window.confirm('Sikker på at du vil slette ' + profileName + '?')) {
        save(self.$form, '/api/profiles/' + profileID, 'DELETE')
        .done(function(data) {
          self.$form.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadProfiles(0);
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
          self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });
  }
};


//
// PRINTERS
//
const PrinterHandler = {
  $printerSelector: $('#printer_selector'),
  $form: $('#printer_form'),
  init: function() {
    this.bindUIActions();
    this.showPrinter('0');
  },
  reloadPrinters: function(id) {
    $.when(getPrinters(id))
    .then(function() {
      this.showPrinter(id);
    }.bind(this));
  },
  showPrinter: function(printerID) {
    if (printerID == '0') {
      clear(this.$form);
    } else {
      populate(this.$form, this.$printerSelector.children().filter(':selected').data('printer'));
    }
  },
  bindUIActions: function() {
    const self = this;

    this.$printerSelector.change(function() {
      self.showPrinter($(this).val());
    });

    $('#save_printer').click(function() {
      let branchChanged = false;
      let hasSubscribers = false;
      const is_edit = self.$printerSelector.val() != "0"
      if (is_edit) {
        const oldData = self.$printerSelector.children().filter(':selected').data('printer')
        const newBranchID = self.$form.find('#printer_branches').val()
        branchChanged = oldData.branch_id != newBranchID
        hasSubscribers = oldData.has_subscribers
      }

      let confirmMessage = "NB! Denne skriveren er satt som standard i nåværende filial/avdeling. "
      confirmMessage += "Husk å rydde opp hvis du fortsetter."
      if (!branchChanged || !hasSubscribers || window.confirm(confirmMessage)) {
        save(self.$form, '/api/printers/', 'POST')
        .done(function(data) {
          self.$form.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadPrinters(data.id);
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
          self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });

    $('#clone_printer').click(function() {
      const printerID = self.$printerSelector.val();
      if (printerID != '0') {
        self.showPrinter(printerID);
        self.$form.find('[name="name"]').val("klone");
        self.$form.find('[name="id"]').val("0"); // hmm
      }
    });

    $('#delete_printer').click(function() {
      const id = self.$printerSelector.val();
      const name = self.$form.find('[name="name"]').val();

      if (id != '0' && window.confirm('Sikker på at du vil slette ' + name + '?')) {
        save(self.$form, '/api/printers/' + id, 'DELETE')
        .done(function(data) {
          self.$form.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadPrinters(0);

          // on deletion, also refresh affiliate view
          getBranches($('#affiliate_branches'));
          getDepartments($('#affiliate_departments'));
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
          self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });
  }
};

//
// PRINTER PROFILES
//
const PrinterProfileHandler = {
  $printerProfileSelector: $('#printer_profile_selector'),
  $form: $('#printer_profile_form'),
  init: function() {
    this.bindUIActions();
    this.showPrinterProfile('0');
  },
  reloadPrinterProfiles: function(id) {
    $.when(getPrinterProfiles(id))
    .then(function() {
      this.showPrinterProfile(id);
    }.bind(this));
  },
  showPrinterProfile: function(id) {
    if (id == '0') {
      clear(this.$form);
    } else {
      populate(this.$form, this.$printerProfileSelector.children().filter(':selected').data('printer_profile')); // is correct?!
    }
  },
  bindUIActions: function() {
    const self = this;

    this.$printerProfileSelector.change(function() {
      self.showPrinterProfile($(this).val());
    });

    $('#save_printer_profile').click(function() {
      save(self.$form, '/api/printer_profiles/', 'POST')
      .done(function(data) {
        self.$form.find('span.info').html(data.message).show().fadeOut(5000);
        self.reloadPrinterProfiles(data.id);
      })
      .fail(function(jqXHR, textStatus, errorThrown) {
        self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    });

    $('#clone_printer_profile').click(function() {
      const id = self.$printerProfileSelector.val();
      if (id != '0') {
        self.showPrinterProfile(id);
        self.$form.find('[name="name"]').val("klone");
        self.$form.find('[name="id"]').val("0");
      }
    });

    $('#delete_printer_profile').click(function() {
      const id = self.$printerProfileSelector.val();
      const name = self.$form.find('[name="name"]').val();

      if (id != '0' && window.confirm('Sikker på at du vil slette ' + name + '?')) {
        save(self.$form, '/api/printer_profiles/' + id, 'DELETE')
        .done(function(data) {
          self.$form.find('span.info').html(data.message).show().fadeOut(5000);
          self.reloadPrinterProfiles(0);
          PrinterHandler.reloadPrinters(0);
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
          self.$form.find('span.error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      }
    });
  }
};



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
  getClients(), getBranches(), getDepartments(), getRequests(), getAdmins(), getProfiles(), getPrinterProfiles(), getPrinters()
).then(function() {
  ViewHandler.init();
  AffiliateHandler.init();
  AdminHandler.init();
  ProfileHandler.init();
  PrinterProfileHandler.init();
  PrinterHandler.init();
  $('.taskpane:first').find('span.progress').hide();
}).fail(function() {
  const message = "NB! Kritisk feil. Kunne ikke laste inn dataene";
  $('.tasktabs li').off('click');
  $('.taskpane').hide();
  $('.taskpane:last').show();
  $('.taskpane:last').find('span.error').html(message).show();
  $('.taskpane:first').find('span.progress').hide();
});
});
