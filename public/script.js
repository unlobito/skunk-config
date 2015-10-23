// http://phpjs.org/functions/base64_encode/
function base64_encode(data) {
  var b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  var o1, o2, o3, h1, h2, h3, h4, bits, i = 0,
    ac = 0,
    enc = '',
    tmp_arr = [];

  if (!data) {
    return data;
  }

  do { // pack three octets into four hexets
    o1 = data.charCodeAt(i++);
    o2 = data.charCodeAt(i++);
    o3 = data.charCodeAt(i++);

    bits = o1 << 16 | o2 << 8 | o3;

    h1 = bits >> 18 & 0x3f;
    h2 = bits >> 12 & 0x3f;
    h3 = bits >> 6 & 0x3f;
    h4 = bits & 0x3f;

    // use hexets to index into b64, and append result to encoded string
    tmp_arr[ac++] = b64.charAt(h1) + b64.charAt(h2) + b64.charAt(h3) + b64.charAt(h4);
  } while (i < data.length);

  enc = tmp_arr.join('');

  var r = data.length % 3;

  return (r ? enc.slice(0, r - 3) : enc) + '==='.slice(r || 3);
}

// http://phpjs.org/functions/base64_decode/
function base64_decode(data) {
  var b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  var o1, o2, o3, h1, h2, h3, h4, bits, i = 0,
    ac = 0,
    dec = '',
    tmp_arr = [];

  if (!data) {
    return data;
  }

  data += '';

  do { // unpack four hexets into three octets using index points in b64
    h1 = b64.indexOf(data.charAt(i++));
    h2 = b64.indexOf(data.charAt(i++));
    h3 = b64.indexOf(data.charAt(i++));
    h4 = b64.indexOf(data.charAt(i++));

    bits = h1 << 18 | h2 << 12 | h3 << 6 | h4;

    o1 = bits >> 16 & 0xff;
    o2 = bits >> 8 & 0xff;
    o3 = bits & 0xff;

    if (h3 == 64) {
      tmp_arr[ac++] = String.fromCharCode(o1);
    } else if (h4 == 64) {
      tmp_arr[ac++] = String.fromCharCode(o1, o2);
    } else {
      tmp_arr[ac++] = String.fromCharCode(o1, o2, o3);
    }
  } while (i < data.length);

  dec = tmp_arr.join('');

  return dec.replace(/\0+$/, '');
}

$(document).ready(function() {
  var data = window.location.hash.substr(1);

  if (data !== "") {
    data = JSON.parse(base64_decode(data));

    renderData(data);
  }
});

function collectData(strictValidation) {
  strictValidation = typeof strictValidation !== 'undefined' ? strictValidation : false;

  data = { "barcodes": [] };

  for (i=0;i<8;i++) {
    if ($("[name='barcode_" + i + "_name']").val() == "" || $("[name='barcode_" + i + "_type']").val() == null || $("[name='barcode_" + i + "_data']").val() == "") {
      continue;
    }

    if (strictValidation && $("[name='barcode_" + i + "_type']").val() == "ean13" && $("[name='barcode_" + i + "_data']").val().length !== 13) {
      alert("EAN-13 barcodes must have 13 numbers!");
      return false;
    }

    if (strictValidation && $("[name='barcode_" + i + "_type']").val() == "ean8" && $("[name='barcode_" + i + "_data']").val().length !== 8) {
      alert("EAN-8 barcodes must have 8 numbers!");
      return false;
    }

    if (strictValidation && $("[name='barcode_" + i + "_type']").val() == "upca" && $("[name='barcode_" + i + "_data']").val().length !== 12) {
      alert("UPC-A barcodes must have 12 numbers!");
      return false;
    }

    if (strictValidation && $("[name='barcode_" + i + "_type']").val() == "rationalizedCodabar") {
      firstChar = $("[name='barcode_" + i + "_data']").val().substr(0, 1);
      lastChar = $("[name='barcode_" + i + "_data']").val().substr($("[name='barcode_" + i + "_data']").val().length-1, 1);

      if (firstChar !== "A" && firstChar !== "B" && firstChar !== "C" && firstChar !== "D") {
        alert("Codabars must begin and end with A, B, C, or D!");
        return false;
      }

      if (lastChar !== "A" && lastChar !== "B" && lastChar !== "C" && lastChar !== "D") {
        alert("Codabars must begin and end with A, B, C, or D!");
        return false;
      }
    }

    data.barcodes.push ({
      name: $("[name='barcode_" + i + "_name']").val(),
      type: $("[name='barcode_" + i + "_type']").val(),
      data: $("[name='barcode_" + i + "_data']").val()
    });
  }

  return data;
}

function raiseBarcode(i) {
  var data = collectData(false);

  var tmp = data.barcodes[i-1];
  data.barcodes[i-1] = data.barcodes[i];
  data.barcodes[i] = tmp;

  renderData(data);
}

function lowerBarcode(i) {
  var data = collectData(false);

  var tmp = data.barcodes[i+1];
  data.barcodes[i+1] = data.barcodes[i];
  data.barcodes[i] = tmp;

  renderData(data);
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

      $("#btn_down_" + i).css("display", "none");
      $("#btn_up_" + i).css("display", "none");
    } else {
      $("#UIBarcode" + i).css("display", "block");

      $("[name='barcode_" + i + "_name']").val(data.barcodes[i].name);
      $("[name='barcode_" + i + "_type']").val(data.barcodes[i].type);
      $("[name='barcode_" + i + "_data']").val(data.barcodes[i].data);
      restrictInput(data.barcodes[i].type, i);

      if (i == 0) {
        $("#btn_up_" + i).css("display", "none");
      } else {
        $("#btn_up_" + i).css("display", "block");
      }

      if (i == data.barcodes.length-1) {
        $("#btn_down_" + i).css("display", "none");
      } else {
        $("#btn_down_" + i).css("display", "block");
      }
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

  if (data.barcodes.length != 0) {
    $("#btn_down_" + (data.barcodes.length-1)).css("display", "block");
    $("#btn_up_" + data.barcodes.length).css("display", "block");
  }

  $('html, body').animate({
        scrollTop: $("#UIBarcode" + data.barcodes.length).offset().top
    }, 2000);
}

function generatePebbleURL() {
  data = collectData(true);

  if (!data) {
    return;
  }

  data_str = base64_encode(JSON.stringify(data));

  location.href = 'pebblejs://close#' + data_str;
}

function restrictInput(value, i) {
  switch (value) {
    case 'code39':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 6);
      $("[name='barcode_" + i + "_data']").attr("pattern", "");
      break;

    case 'code128':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 16);
      $("[name='barcode_" + i + "_data']").attr("pattern", "");
      break;

    case 'upca':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 12);
      $("[name='barcode_" + i + "_data']").attr("pattern", "\\d*");
      break;

    case 'ean13':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 13);
      $("[name='barcode_" + i + "_data']").attr("pattern", "\\d*");
      break;

    case 'ean8':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 8);
      $("[name='barcode_" + i + "_data']").attr("pattern", "\\d*");
      break;

    case 'rationalizedCodabar':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 11);
      $("[name='barcode_" + i + "_data']").removeAttr("pattern");
      break;

    case 'interleaved2of5':
      $("[name='barcode_" + i + "_data']").attr("maxlength", 13);
      $("[name='barcode_" + i + "_data']").removeAttr("pattern");
      break;

    default:
      $("[name='barcode_" + i + "_data']").attr("maxlength", "");
      $("[name='barcode_" + i + "_data']").removeAttr("pattern");
      break;
  }
}

function importBarcode(i) {
  $("#camera_input_" + i).click();
}

function importBarcodeUpload(i) {
  // http://stackoverflow.com/questions/166221/how-can-i-upload-files-asynchronously
  var formData = new FormData($("#camera_input_form_" + i)[0]);

  $.ajax({
    url: "/decode",
    type: "POST",
    data: formData,

    // Events
    success: importBarcodeSuccess,
    error: importBarcodeError,

    // Stop pre-processing
    cache: false,
    contentType: false,
    processData: false,

    // Callback data
    barcodeId: i
  });
}

function importBarcodeSuccess(data) {
  $("[name='barcode_" + this.barcodeId + "_data']").val(data);
}

function importBarcodeError() {
  alert("Sorry! Something went wrong. Please try again.")
}
