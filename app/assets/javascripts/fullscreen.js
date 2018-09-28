window.GetIframeTransforms = function(_window, _screen) {
  var MAX_WIDTH = 2000;
  // Scale iframe, but make sure that:
  // 1. Iframe is smaller than MAX_WIDTH which should be enough for all the documents. It prevents creating
  //    some huge CODAP canvases on really big screens (e.g. 4k monitors).
  // 2. Iframe is not smaller than size of the current window.
  var width  = Math.max(_window.innerWidth, Math.min(MAX_WIDTH, _screen.width));
  var scale  = _window.innerWidth  / width;
  var height = _window.innerHeight / scale;
  return {
    scale: scale,
    width: width,
    height: height
  };
}
function fullscreenSupport (iframe) {
  var $target = $(iframe);
  function setScaling () {
    if (!screenfull.isFullscreen) {
      var trans = GetIframeTransforms(window, screen);
      $target.css('width', trans.width);
      $target.css('height', trans.height);
      $target.css('transform-origin', 'top left');
      $target.css('transform', 'scale3d(' + trans.scale + ',' + trans.scale + ',1)');
    } else {
      // Disable scaling in fullscreen mode.
      $target.css('width', '100%');
      $target.css('height', '100%');
      $target.css('transform', 'scale3d(1,1,1)');
    }
    // Help text.
    $('#fullscreen-help').css('fontSize', Math.round(Math.pow(window.innerWidth / 5, 0.65)) + 'px');
  }

  function setupFullsceenButton () {
    $('#fullscreen-help').show();
    var $button = $('.fullscreen-icon');
    $button.show();
    $button.on('click', function () {
      if (!screenfull.isFullscreen) {
        screenfull.request();
      } else {
        screenfull.exit();
      }
    });
    document.addEventListener(screenfull.raw.fullscreenchange, function () {
      if (screenfull.isFullscreen) {
        $button.addClass('fullscreen');
      } else {
        $button.removeClass('fullscreen');
      }
    });
  }

  setScaling();
  if (screenfull.enabled) {
    setupFullsceenButton();
  }
  $(window).on('resize', setScaling);
}
