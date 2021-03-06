# frozen_string_literal: true

require 'rails_helper'

describe 'Create a study' do
  let(:user) { create :admin }

  setup do
    create :faculty_sponsor, name: 'Jack Sponsor'
    create :data_release_study_type, name: 'genomic sequencing'
    create :study_type
    create :program
  end
  it 'displays the expected fields' do
    login_user user
    visit root_path
    click_link 'Create Study'
    expect(page).to have_field('Study name', type: :text)
    expect(page).to have_field('Faculty Sponsor', type: :select)
    expect(page).to have_field('Study description', type: :textarea)

    within_fieldset('Do any of the samples in this study contain human DNA?') do
      expect(page).to have_field('Yes', type: :radio)
      expect(page).to have_field('No', type: :radio)
    end

    within_fieldset('Does this study contain samples that are contaminated with human DNA which must be removed prior to analysis?') do
      expect(page).to have_field('Yes', type: :radio)
      expect(page).to have_field('No', type: :radio)
    end

    within_fieldset('Does this study require the removal of X chromosome and autosome sequence?') do
      expect(page).to have_field('Yes', type: :radio)
      expect(page).to have_field('No', type: :radio)
    end

    within_fieldset('What is the data release strategy for this study?') do
      expect(page).to have_field('Open (ENA)', type: :radio)
      expect(page).to have_field('Managed (EGA)', type: :radio)
      expect(page).to have_field('Not Applicable (Contact Datasharing)', type: :radio)
    end

    within_fieldset('Study Visibility') do
      expect(page).to have_field('Hold', type: :radio)
      expect(page).to have_field('Public', type: :radio)
    end

    expect(page).to have_field('What sort of study is this?', type: :select)
    expect(page).to have_field('How is the data release to be timed?', type: :select)
    expect(page).to have_field('Prelim ID', type: :text)

    click_button 'Create'

    expect(page).to have_content "Name can't be blank"
    expect(page).to have_content "Study description can't be blank"
  end

  it 'create managed study', js: true do
    login_user user
    visit root_path
    click_link 'Create Study'
    expect(page).to have_content('Study Create')
    choose('Managed (EGA)', allow_label_click: true)
    expect(page).to have_content('HMDMC approval number')
    click_button 'Create'
    expect(page).not_to have_content "Study metadata hmdmc approval number can't be blank"
  end

  it 'create open study', js: true do
    login_user user
    visit new_study_path
    expect(page).to have_content('Study Create')
    expect(page).to have_content('Alignments in BAM')
    bam = find('#study_study_metadata_attributes_bam')
    expect(bam).to be_checked
    uncheck 'study_study_metadata_attributes_bam'
    expect(bam).not_to be_checked
    fill_in 'Study name', with: 'new study'
    fill_in 'Study description', with: 'writing cukes'
    fill_in 'ENA Study Accession Number', with: '12345'
    fill_in 'Study name abbreviation', with: 'CCC3'
    select('Jack Sponsor', from: 'Faculty Sponsor')

    within_fieldset 'Do any of the samples in this study contain human DNA?' do
      choose('Yes', allow_label_click: true)
    end

    within_fieldset 'Does this study contain samples that are contaminated with human DNA which must be removed prior to analysis?' do
      choose('No', allow_label_click: true)
    end

    within_fieldset 'Does this study require the removal of X chromosome and autosome sequence?' do
      choose('No', allow_label_click: true)
    end

    within_fieldset 'Are all the samples to be used in this study commercially available, unlinked anonymised cell-lines?' do
      choose('Yes', allow_label_click: true)
    end

    choose('Open (ENA)', allow_label_click: true)
    expect(page).not_to have_content('HMDMC approval number')
    click_button 'Create'
    expect(page).to have_content('Your study has been created')

    study = Study.last
    expect(page).to have_current_path("/studies/#{study.id}/information")
    expect(study.abbreviation).to eq 'CCC3'
    expect(study.study_metadata.bam).to eq false
  end
end
