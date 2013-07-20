require 'spec_helper'
require "benchmark"

describe "interacting with javascript", :type => :feature do
  before do
    visit "file://#{File.join(File.dirname(__FILE__), 'fixture.html')}"
  end

  it 'shows a character' do
    expect(page).to have_content 'Sharoar Dewshining'
    # Waits for the page to load the matching character, no problem there.
  end

  describe 'non-deterministic matchers' do
    context 'when the character\'s class is selected' do
      before do
        select 'Avenger'
      end

      it 'still shows the character' do
        expect(page).to have_content 'Sharoar Dewshining'
        # This passed but did we find character before or after the filter was applied?
        # The character we were looking for was already on the page so this will pass even if no JS has had time to run.
      end
    end

    context 'when a different class is selected' do
      before do
        select 'Barbarian'
      end

      it 'no longer shows the character' do
        expect(page).to_not have_content 'Sharoar Dewshining'
        # At some point the character was removed from the page but that could just have been in preparation for loading the filtered list which will replace it.
        # This character could reappear on the page when our filter finishes running and the test would (sometimes) still pass.
        # Change the before block to select the character's class and this test will still pass.
      end
    end

    describe 'waiting for a loading indicator' do
      it 'we can just wait for the page not to finish loading' do
        expect(page).to have_content 'Sharoar Dewshining'
        select 'Avenger'
        expect(page).to_not have_css '.loading'
        # JS has not had time to set the loading state yet
        sleep 0.5
        # now we set the loading state, too bad we're already executing our assertion
        expect(page).to_not have_content 'Sharoar Dewshining'
        # list has been cleared so our expectation passes but JS is not finished
        # uncomment the following lines to see the test fail
        # sleep 1
        # expect(page).to_not have_content 'Sharoar Dewshining'
      end

      it 'ok but this will totally work now right?' do
        expect(page).to have_content 'Sharoar Dewshining'
        select 'Barbarian'
        # sleep 3
        # uncomment the above sleep and the test fails as we start looking for the loading state after it has been dismissed
        expect(page).to have_css '.loading'
        expect(page).to_not have_css '.loading'
        expect(page).to_not have_content 'Sharoar Dewshining'
      end
    end

    describe 'waiting for a specific indicator' do
      it 'is deterministic but brittle' do
        expect(page).to have_content 'Sharoar Dewshining'
        select 'Barbarian'
        within '#filter_title' do
          expect(page).to have_content 'Barbarian'
        end
        expect(page).to_not have_content 'Sharoar Dewshining'
        # Success! Finally we have a test which is not vulnerable to race conditions between Ruby and JavaScript.
        # Unfortunately it depends on #filter_title's content being the last DOM element to change to indicate that our JS is finished running.
        # If we refactor our JS and update this header before the filter is applied our tests will be exposed to race conditions again.
      end
    end
  end

  describe 'matcher performance' do
    it 'has_content passes' do
      time = Benchmark.measure do
        expect(page.has_content? 'Sharoar Dewshining').to be_true
        # will return as soon as matching content can be found on the page
        # will fail if no content matches before the default_wait_time is reached
      end
      puts time.format "has_content? in %r"
    end

    it 'inverting a matcher can have significantly different performance' do
      time = Benchmark.measure do
        expect(page.has_no_content? 'Sharoar Dewshining').to be_true
        # passes as soon as the page does not contain the content, immediately in this case
      end
      puts time.format "has_no_content? in %r"
    end

    it 'waiting on a matcher to timeout leads to slow tests' do
      time = Benchmark.measure do
        expect(page.has_content? 'something we will never find').to be_false
      end
      puts time.format "has_content? timeout in %r, Capybara.default_wait_time=#{Capybara.default_wait_time}"
    end

    it '"all" inspects only the current page state' do
      time = Benchmark.measure do
        expect(page.all('td', text: 'Sharoar Dewshining')).to be_empty #no cells loaded yet so this passes
      end
      puts time.format "all matcher in %r"
    end
  end

  describe 'mistakes and anti-patterns' do
    it 'incredibly slow matcher combinations' do
      expect(page).to have_content 'Hollyonna Madwar'
      time = Benchmark.measure do
        page.all('td').any? do |cell|
          # get every table cell on the page and for each of them
          cell.text.include?('Hollyonna Madwar')
          # wait for up to the Capybara default_wait_time for its content to match the expected value before moving on
          # we're waiting a full 2 seconds for each non-matching cell until we eventually hit the cell we are looking for
        end
      end
      puts time.format "iterating test passed in %r"
    end

    describe 'inverting RSpec matchers' do
      RSpec::Matchers.define :have_character do |expected|
        match do |actual|
          page.find('#characters_list').has_content? expected
        end
      end

      before do
        page.first('#characters_list tr')
      end

      it 'performs poorly when reversed' do
        time = Benchmark.measure do
          expect(page).to have_character 'Leonan Darksbane'
        end
        puts time.format "to have_character in %r"

        time = Benchmark.measure do
          expect(page).to_not have_character 'not present'
        end
        puts time.format "to_not have_character in %r"
      end
    end
  end
end
