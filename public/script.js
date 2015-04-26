$(document).ready(function() {
  var data = window.location.hash.substr(1);

  if (data !== "") {
    data = JSON.parse(decodeURIComponent(data));

    renderData(data);
  }
});

function collectData() {
  data = { "barcodes": [] };

  for (i=0;i<8;i++) {
    if ($("[name='barcode_" + i + "_name']").val() == "" || $("[name='barcode_" + i + "_data']").val() == "") {
      continue;
    }

    data.barcodes.push ({
      name: $("[name='barcode_" + i + "_name']").val(),
      type: $("[name='barcode_" + i + "_type']").val(),
      data: $("[name='barcode_" + i + "_data']").val()
    });
  }

  if (data.barcodes.length > 1) {
    data.barcodes = data.barcodes.sort(function(x, y) {
      if (x.name < y.name) {
        return -1;
      }
      if (x.name > y.name) {
        return 1;
      }
      return 0;
    });
  }

  return data;
}

function clearBarcode(i) {
  $("[name='barcode_" + i + "_name']").val("");
  $("[name='barcode_" + i + "_type']").val("");
  $("[name='barcode_" + i + "_data']").val("");

  refreshView();
}

function renderData(data) {
  for (i=0;i<8;i++) {
    if (data.barcodes[i] == undefined) {
      if (i != 0) {
        $("#UIBarcode" + i).css("display", "none");
      }

      $("[name='barcode_" + i + "_name']").val("");
      $("[name='barcode_" + i + "_type']").val("");
      $("[name='barcode_" + i + "_data']").val("");
    } else {
      $("#UIBarcode" + i).css("display", "block");

      $("[name='barcode_" + i + "_name']").val(data.barcodes[i].name);
      $("[name='barcode_" + i + "_type']").val(data.barcodes[i].type);
      $("[name='barcode_" + i + "_data']").val(data.barcodes[i].data);
    }
  }
}

function refreshView() {
  data = collectData();
  renderData(data);
}

function addBarcode() {
  refreshView();

  data = collectData();
  $("#UIBarcode" + data.barcodes.length).css("display", "block");

  $('html, body').animate({
        scrollTop: $("#UIBarcode" + data.barcodes.length).offset().top
    }, 2000);
}

function generatePebbleURL() {
  data = collectData();

  data_str = JSON.stringify(data);

  location.href = 'pebblejs://close#' + data_str;
}
