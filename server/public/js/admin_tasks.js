"use strict";


$(function() {

  var clients;

  var load = function(url) {
    return $.ajax({
      url: url,
      type: "GET",
      dataType: "json",
      contentType: "application/json; charset=UTF-8",
      cache: false
    });
  };


  var loadClients = function() {
    var request = load("/api/clients/");

    request.done(function(data) {
      clients = data.clients;

      var selector = $(".client_selector");
      data.clients.forEach(client => {
        selector.append("<option class='clients branch-" + client.branch_id +
        "' value='" + client.id + "'>" + client.name + "</option>");
       })
    })};


  var loadRequests = function() {
    var request = load("/api/requests/");

    request.done(function(data) {
      data.requests.forEach(branch => {
        $("#request_selector").append('<option value=' + request.id + '>' + request.name + '</option>');
      })
    });
  };


  var loadBranches = function() {
    var request = load("/api/branches/");

    request.done(function(data) {
      data.branches.forEach(branch => {
        $(".branch_selector").append('<option value=' + branch.id + '>' + branch.name + '</option>');
      })
    });
  };


  var loadDepartments = function() {
    var request = load("/api/departments/");

    request.done(function(data) {
      data.departments.forEach(department => {
        $(".department_selector").append('<option class="departments branch-' +
        department.branch_id + '" value=' + department.id + '>' + department.name + '</option>');
      })
    });
  };




  $(".branch_selector.edit").change(function() {
    var branchID = $(this).val();
    var clientSelector = $('.client_selector');

    clientSelector.find('.clients').prop("hidden", true);
    clientSelector.find('.branch-' + branchID).prop("hidden", false);
    clientSelector.find('.branch-' + branchID).first().prop('selected', true);
    //$(".client_selector").change();
  });

  $("#edit_client_form .branch_selector").change(function() {
    var branchID = $(this).val();

    $('.departments').prop('hidden', true);
    $('.branch-' + branchID).prop('hidden', false);
    $(".department_selector .branch-" + branchID).first().prop("selected", true);
  });



  $(".client_selector").change(function() {
    var clientID = $(this).val();
    var form = $("#edit_client_form");

    // populate form
    clients.forEach(client => {
      if (client.id === parseInt(clientID)) {
        form.find('.branch_selector').val(client.branch_id).change();

        $.each(client, function(name, val){
          var formElement = form.find('[name="'+name+'"]');
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
      }
    });

    //form.find('.department_selector').
    //$("#client_dept_selector .depts").prop("disabled", true).prop("hidden", true);
    //$("#client_dept_selector .branch-" + branchID).prop("disabled", false).prop("hidden", false).first().prop("selected", true);
  });

  $("#request_selector").change(function() {
    var requestID = $(this).val();
    var request = $("#request-" + requestID);
    var form = $("#add_client_form");

    form.find("#name").val("");
    form.find("#request_id").val(requestID);
    form.find("#hwaddr").val(request.data("hwaddr"));
    form.find("#ipaddr").val(request.data("ipaddr"));

    form.find("#shorttime").prop("checked", false);
    form.find("#test").prop("checked", false);
    form.find("#client_screen_res option[value='1']").prop("selected", true);

    //form.find("#client_branch_selector option[value=" + client.data("branch_id") + "]").prop("selected", true);
    //form.find("#client_dept_selector option[value=" + client.data("department_id") + "]").prop("selected", true);
  });


  $('#save_client_changes').click(function() {
    var foo = $('#edit_client_form').serializeArray();
    var json = {};

    $.each(foo, function() {
      json[this.name] = this.value || '';
    });

    var payload = {payload: json};

    json = JSON.stringify(json);

    var request = $.ajax({
      url: '/api/clients/',
      type: 'PUT',
      data: JSON.stringify(payload),
      dataType: "json",
      contentType: "application/json; charset=UTF-8"
    });

    request.done(function(msg) {
      console.log("gikk bra: " + msg);
    })

    request.fail(function(jqXHR, textStatus, errorThrown) {
      console.log("gikk skitt gitt")
    });
  })


  loadClients();
  loadBranches();
  loadDepartments();


  $(".clients").prop("disabled", true).prop("hidden", true);
  $("#branch_selector option:first").prop("selected", true);
  $("#branch_selector").change();
  $("#request_selector option:first").prop("selected", true);


});
