feature 'Document', :codap do
  describe 'report' do
    let(:author)   { FactoryGirl.create(:user, username: 'author') }
    let(:student)  { FactoryGirl.create(:user, username: 'student') }
    let(:teacher)  { FactoryGirl.create(:user, username: 'teacher') }
    let(:template) { FactoryGirl.create(:document,
      title: "template", shared: true, owner_id: author.id,
      form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }') }
    let(:student_doc1a) { FactoryGirl.create(:document,
      title: "student1a", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz1a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:student_doc1b) { FactoryGirl.create(:document,
      title: "student1b", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz1b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:student_doc1c) { FactoryGirl.create(:document,
      title: "student1c", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz1c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:student_doc2a) { FactoryGirl.create(:document,
      title: "student2a", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz2a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:student_doc2b) { FactoryGirl.create(:document,
      title: "student2b", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz2b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:student_doc2c) { FactoryGirl.create(:document,
      title: "student2c", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz2c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:anon_doc1a) { FactoryGirl.create(:document,
      title: "anon1a", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz1a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:anon_doc1b) { FactoryGirl.create(:document,
      title: "anon1b", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz1b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:anon_doc1c) { FactoryGirl.create(:document,
      title: "anon1c", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz1c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:anon_doc2a) { FactoryGirl.create(:document,
      title: "anon2a", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz2a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:anon_doc2b) { FactoryGirl.create(:document,
      title: "anon2b", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz2b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:anon_doc2c) { FactoryGirl.create(:document,
      title: "anon2c", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz2c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:server)   { 'http://foo.com/' }

    scenario 'user needs to be logged in to view non-anonymous work' do
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content 'No documents have been saved!'
      signin(teacher.email, teacher.password)
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'user does not need to be logged in to view anonymous work' do
      url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo', runAsGuest: 'true'})
      url2 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url1}']"
      signin(teacher.email, teacher.password)
      visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url2}']"
    end
    scenario 'the template document needs to exist' do
      signin(teacher.email, teacher.password)
      visit report_path(owner: author.username, recordname: template.title + "2", server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content "Error: The requested document could not be found."
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'runKey needs to be provided' do
      signin(teacher.email, teacher.password)
      expect {
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username)
      }.to raise_error(ActiveRecord::RecordNotFound)
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'server needs to be provided' do
      signin(teacher.email, teacher.password)
      expect {
        visit report_path(owner: author.username, recordname: template.title, reportUser: student.username, runKey: 'foo')
      }.to raise_error(ActiveRecord::RecordNotFound)
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'user can report a document via owner and recordname' do
      signin(teacher.email, teacher.password)
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'user can report a document via owner and doc' do
      signin(teacher.email, teacher.password)
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, doc: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'user can report a document via recordid' do
      signin(teacher.email, teacher.password)
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordid: template.id, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'user can report a document via moreGames' do
      signin(teacher.email, teacher.password)
      visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'reportUser also has multiple documents that match the run key, a link to each of them is displayed too' do
      signin(teacher.email, teacher.password)
      url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url2 = doc_url(server, {recordid: student_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 2)
      expect(page).to have_selector "a.launch-button[href='#{url1}']"
      expect(page).to have_selector "a.launch-button[href='#{url2}']"
    end
    scenario 'reportUser also has documents that do not match the run key, a link to each of them is not also displayed' do
      signin(teacher.email, teacher.password)
      url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url2 = doc_url(server, {recordid: student_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url3 = doc_url(server, {recordid: student_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url4 = doc_url(server, {recordid: student_doc2a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url5 = doc_url(server, {recordid: student_doc2b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 3)
      expect(page).to have_selector "a.launch-button[href='#{url1}']"
      expect(page).to have_selector "a.launch-button[href='#{url2}']"
      expect(page).to have_selector "a.launch-button[href='#{url3}']"
    end
    scenario 'moreGames in url and one document with run key, 1 link is present' do
      signin(teacher.email, teacher.password)
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'moreGames in url and multiple documents with run key, all links are present' do
      signin(teacher.email, teacher.password)
      url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url2 = doc_url(server, {recordid: student_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
      expect(page).to have_selector('.launch-button', count: 2)
      expect(page).to have_selector "a.launch-button[href='#{url1}']"
      expect(page).to have_selector "a.launch-button[href='#{url2}']"
    end
    describe 'anonymous' do
      scenario 'user can report a document via owner and recordname' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via owner and doc' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, doc: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via recordid' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordid: template.id, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via moreGames' do
        signin(teacher.email, teacher.password)
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
        expect(page).to have_content 'No documents have been saved!'
      end
      scenario 'reportUser also has multiple documents that match the run key, a link to each of them is displayed too' do
        signin(teacher.email, teacher.password)
        url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: anon_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 2)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
      scenario 'reportUser also has documents that do not match the run key, a link to each of them is not also displayed' do
        signin(teacher.email, teacher.password)
        url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: anon_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url3 = doc_url(server, {recordid: anon_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url4 = doc_url(server, {recordid: anon_doc2a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url5 = doc_url(server, {recordid: anon_doc2b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 3)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
        expect(page).to have_selector "a.launch-button[href='#{url3}']"
      end
      scenario 'moreGames in url and one document with run key, 1 link is present' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'moreGames in url and multiple documents with run key, all links are present' do
        signin(teacher.email, teacher.password)
        url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: anon_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 2)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
    end
    describe 'auto authentication' do
      scenario 'the user will not be authenticated if auth_provider is set and the user is not logged in' do
        visit report_path(auth_provider: 'http://bar.com', owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_content 'No documents have been saved!'
      end
      scenario 'the user will be authenticated if referrer is set and the user is not logged in' do
        Capybara.current_session.driver.header 'Referer', 'http://bar.com/portal/offerings/1/report'
        expect {
          visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        }.to raise_error(ActionController::RoutingError) # capybara doesn't handle the redirects well
        expect(page.current_url).to match 'http://bar.com/auth/concord_id/authorize'
      end
      scenario 'the user will not be authenticated if auth_provider is set and the user is logged in' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(auth_provider: 'http://bar.com', owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
    end
  end
end