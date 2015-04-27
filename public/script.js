$(document).ready(function() {
  var data = window.location.hash.substr(1);

  if (data !== "") {
    data = JSON.parse(decodeURIComponent(data));

    renderData(data);
  }
});

function collectData(strictValidation) {
  strictValidation = typeof strictValidation !== 'undefined' ? strictValidation : false;

  data = { "barcodes": [] };

  for (i=0;i<8;i++) {
    if ($("[name='barcode_" + i + "_name']").val() == "" || $("[name='barcode_" + i + "_data']").val() == "") {
      continue;
    }

    if (strictValidation && $("[name='barcode_" + i + "_type']").val() == "ean13" && $("[name='barcode_" + i + "_data']").val().length !== 13) {
      alert("EAN-13 barcodes must have 13 numbers!");
      return false;
    }

    if (strictValidation && $("[name='barcode_" + i + "_type']").val() == "upca" && $("[name='barcode_" + i + "_data']").val().length !== 12) {
      alert("UPC-A barcodes must have 12 numbers!");
      return false;
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
      restrictInput(data.barcodes[i].type, i);
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
  data = collectData(true);

  if (!data) {
    return;
  }

  data_str = JSON.stringify(data);

  location.href = 'pebblejs://close#' + data_str;
}

function restrictInput(value, i) {
  switch (value) {
    case 'code39':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 6);
      $("[name='barcode_" + i + "_data']").attr("pattern", "\\d*");
      break;

    case 'code128':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 16);
      $("[name='barcode_" + i + "_data']").attr("pattern", "\\d*");
      break;

    case 'upca':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 12);
      $("[name='barcode_" + i + "_data']").attr("pattern", "\\d*");
      break;

    case 'ean13':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 13);
      $("[name='barcode_" + i + "_data']").attr("pattern", "\\d*");
      break;

    default:
      $("[name='barcode_" + i + "_data']").attr("maxlength", "");
      $("[name='barcode_" + i + "_data']").removeAttr("pattern");
      break;
  }
}
