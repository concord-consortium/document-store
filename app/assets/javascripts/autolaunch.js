function autolaunchInteractive (documentId, launchUrl) {
  var CURRENT_VS_LINKED = "Another page contains more recent data. Which would you like to use?";
  var LINKED_VS_LINKED = "There are two possibilities for continuing your work. Which version would you like to use?";

  // Update the loading message after 10 seconds
  var showTimeoutId = setTimeout(function() {
    $('#loading-text').html("Still loading!  You may want to reload this page to try again.")
  }, 10000);

  var phone = iframePhone.getIFrameEndpoint();
  // Variables below are set in `initInteractive` handler.
  var interactiveData = null;
  var mostRecentLinkedState = null;
  var interactiveStateAvailable = false;

  function stateValid (state) {
    return state && state.docStore && state.docStore.recordid && state.docStore.accessKeys && state.docStore.accessKeys.readOnly;
  }

  function showDataSelectDialog () {
    function showPreview (element) {
      $(element).addClass('preview-active');
      $('.overlay').show();
    }
    function hidePreview () {
      $('.preview-active').removeClass('preview-active');
      $('.overlay').hide();
    }

    if (interactiveStateAvailable) {
      $('#question').text(CURRENT_VS_LINKED);
    } else {
      $('#question').text(LINKED_VS_LINKED);
    }

    $('.data-select-dialog').show()
    $('#prev-version-time').text((new Date(mostRecentLinkedState.updatedAt)).toLocaleString());
    $('#current-version-time').text((new Date(interactiveData.interactiveStateUpdatedAt)).toLocaleString());
    $('#prev-version-page-idx').text(mostRecentLinkedState.pageIndex);
    $('#current-version-page-idx').text(interactiveData.pageIndex);
    if (mostRecentLinkedState.pageName) {
      $('#prev-version-page-name').text(' - ' + mostRecentLinkedState.pageName);
    }
    if (interactiveData.pageName) {
      $('#current-version-page-name').text(' - ' + interactiveData.pageName);
    }
    $('#prev-version-activity-name').text(mostRecentLinkedState.activityName);
    $('#current-version-activity-name').text(interactiveData.activityName);

    var currentUrl = interactiveData.interactiveStateUrl;
    var srcCurrent = $.param.querystring(launchUrl, {launchFromLara: Base64.encode(JSON.stringify({ url: currentUrl }))});
    $('#current-version-preview').attr('src', srcCurrent);

    var prevUrl = mostRecentLinkedState.interactiveStateUrl;
    var srcPrev = $.param.querystring(launchUrl, {launchFromLara: Base64.encode(JSON.stringify({ url: prevUrl }))});
    $('#prev-version-preview').attr('src', srcPrev)

    $('.overlay').on('click', hidePreview);
    $('.preview').on('click', function () {
      if ($(this).hasClass('preview-active')) {
        hidePreview();
      } else {
        showPreview(this);
      }
    });
    $('.preview-label').on('click', function () {
      showPreview($(this).closest('.version-info').find('.preview')[0]);
    });
    $('#prev-version-button').on('click', function () {
      // Remove existing interactive state, so the interactive will be initialized from the linked state.
      phone.post('interactiveState', null);
      interactiveStateAvailable = false;
      launchInteractive();
      $('.data-select-dialog').remove();
    });
    $('#current-version-button').on('click', function () {
      // Update current state timestamp, so it will be considered to be the most recent one.
      phone.post('interactiveState', 'touch');
      mostRecentLinkedState = null;
      launchInteractive();
      $('.data-select-dialog').remove();
    });
  }

  function launchInteractive () {
    var linkedState = mostRecentLinkedState && mostRecentLinkedState.data;
    var launchParams = {url: interactiveData.interactiveStateUrl, source: documentId, collaboratorUrls: interactiveData.collaboratorUrls};

    // If there is a linked state and no interactive state then change the source document to point to the linked recordid and add the access key.
    if (stateValid(linkedState) && !interactiveStateAvailable) {
      launchParams.source = linkedState.docStore.recordid;
      launchParams.readOnlyKey = linkedState.docStore.accessKeys.readOnly;
    }
    // Interactive state saves are supported by autolaunch currently only when the app iframed by autolaunch uses
    // the Cloud File Manager (CFM).  The CFM in the iframed app handles all the state saving -- Lara only receives
    // 'nochange' or 'touch' as the state. 'touch' notifies LARA that state has been updated.
    //
    // 1. Autolaunch informs Lara that interactive state is supported using the supportedFeatures message
    // 2. Once the iframed app loads autolaunch sends a cfm::getCommands message to the iframed app and sets a
    //    iframeCanAutosave flag when a cfm::commands is received from the iframed app and the app supports cfm::autosave
    // 3. When autolaunch gets an getInteractiveState request from Lara it either
    //    a. immedatiely returns 'nochange' to Lara when the iframeCanAutosave flag isn't set
    //    b. sends a 'cfm::autosave' message to the app and then sends 'nochange' when the app returns 'cfm::autosaved'

    phone.post('supportedFeatures', {
      apiVersion: 1,
      features: {
        interactiveState: true
      }
    });

    var iframeCanAutosave = false;
    var iframeLoaded = function () {
      $(window).on('message', function (e) {
        var data = e.originalEvent.data
        if (data) {
          switch (data.type) {
            case 'cfm::commands':
              iframeCanAutosave = data.commands && data.commands.indexOf('cfm::autosave') !== -1;
              break;
            case 'cfm::autosaved':
              phone.post('interactiveState', data.saved ? 'touch' : 'nochange');
              break;
          }
        }
      })
      iframe.postMessage({type: 'cfm::getCommands'}, '*')
    };

    phone.addListener('getInteractiveState', function () {
      if (iframeCanAutosave) {
        iframe.postMessage({type: 'cfm::autosave'}, '*');
      }
      else {
        phone.post('interactiveState', 'nochange');
      }
    });

    var src = $.param.querystring(launchUrl, {launchFromLara: Base64.encode(JSON.stringify(launchParams))});
    var iframe = $("#autolaunch_iframe").on('load', iframeLoaded).attr("src", src).show()[0].contentWindow;
  }

  phone.addListener('initInteractive', function (_interactiveData) {
    clearTimeout(showTimeoutId);

    interactiveData = _interactiveData;
    interactiveStateAvailable = stateValid(interactiveData.interactiveState);
    // Use most recent linked state.
    var linkedStates = interactiveData.allLinkedStates;
    mostRecentLinkedState = linkedStates && linkedStates.slice().sort(function (a, b) {
      return new Date(b.updatedAt) - new Date(a.updatedAt)
    })[0];
    var linkedStateTimestamp = stateValid(mostRecentLinkedState && mostRecentLinkedState.data) && new Date(mostRecentLinkedState.updatedAt);
    var currentDataTimestamp = interactiveStateAvailable && new Date(interactiveData.interactiveStateUpdatedAt);

    if (linkedStateTimestamp && currentDataTimestamp && linkedStateTimestamp > currentDataTimestamp) {
      showDataSelectDialog();
    } else {
      launchInteractive();
    }
  });

  phone.addListener('getExtendedSupport', function() {
    phone.post('extendedSupport', { reset: false });
  });

  // TODO: there seems to be a race condition between when the page loads and when initialize can be called
  setTimeout(function () {
    // Initialize connection after all message listeners are added!
    phone.initialize();
  }, 1000);
}