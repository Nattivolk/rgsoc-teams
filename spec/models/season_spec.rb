require 'spec_helper'

describe Season do
  context 'with validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  context 'with callbacks' do
    subject { described_class.new name: Date.today.year }

    context 'before validation' do
      it 'sets starts_at' do
        expect { subject.valid? }.to change { subject.starts_at }.from nil
      end

      it 'sets ends_at' do
        expect { subject.valid? }.to change { subject.ends_at }.from nil
      end

      it 'sets applications_open_at to the beginning of day' do
        date = DateTime.parse('2015-02-22 14:00 GMT+1')
        subject.applications_open_at = date
        expect { subject.valid? }.to \
          change { subject.applications_open_at }.to \
          DateTime.parse('2015-02-22 0:00 UTC')
      end

      it 'sets applications_close_at to the end of day' do
        date = DateTime.parse('2015-02-22 14:00 GMT+1')
        subject.applications_close_at = date
        expect { subject.valid? }.to \
          change { subject.applications_close_at }.to \
          DateTime.parse('2015-02-22 23:59:59 GMT')
      end

      it 'sets acceptance_notification_at to the end of day' do
        date = DateTime.parse('2015-02-22 14:00 GMT+1')
        subject.acceptance_notification_at = date
        expect { subject.valid? }.to \
          change { subject.acceptance_notification_at }.to \
          DateTime.parse('2015-02-22 23:59:59 GMT')
      end

      it 'sets the project_proposals_open_at to the beginning of the day' do
        date = DateTime.parse('2015-02-22 14:00 GMT+1')
        subject.project_proposals_open_at = date
        expect { subject.valid? }.to \
          change { subject.project_proposals_open_at }.to \
          DateTime.parse('2015-02-22 0:00 UTC')
      end

      it 'sets the project_proposals_close_at to the end of the day' do
        date = DateTime.parse('2015-02-22 14:00 GMT+1')
        subject.project_proposals_close_at= date
        expect { subject.valid? }.to \
          change { subject.project_proposals_close_at }.to \
          DateTime.parse('2015-02-22 23:59:59 GMT')
      end
    end
  end

  describe '#application_period?' do
    it 'returns true if today is between open and close date' do
      subject.applications_open_at = 1.week.ago
      subject.applications_close_at = 1.week.from_now
      expect(subject).to be_application_period
    end

    it 'returns false if today is before open date' do
      subject.applications_open_at = 1.day.from_now
      subject.applications_close_at = 1.week.from_now
      expect(subject).not_to be_application_period
    end

    it 'returns false if today is after close date' do
      subject.applications_open_at = 1.week.ago
      subject.applications_close_at = 1.day.ago
      expect(subject).not_to be_application_period
    end
  end

  describe '#applications_open?' do
    it 'returns true if today is past application open date' do
      subject.applications_open_at = 1.week.ago
      expect(subject).to be_applications_open
    end

    it 'returns false' do
      expect(subject).not_to be_applications_open
    end
  end

  describe '#started?' do
    it 'returns true if today is past starts_at' do
      subject.starts_at = 1.week.ago
      expect(subject).to be_started
    end

    it 'returns false' do
      expect(subject).not_to be_started
    end
  end

  describe '#year' do
    it 'returns the name' do
      subject.name = 'foobarbaz'
      expect(subject.year).to eql 'foobarbaz'
    end
  end

  describe '.current' do
    it 'creates a season record' do
      create :season, name: '2000'
      expect { Season.current }.to \
        change { Season.count }.by(1)
    end

    it 'returns the existing season' do
      season = create :season, name: Date.today.year
      expect(Season.current).to eql season
    end
  end

  describe '.succ' do
    subject { Season.succ }
    let(:year) { Date.today.year }

    context 'with existing successor season' do
      let!(:next_season) { Season.create name: year+1 }

      it 'returns the existing follow-up season' do
        expect { subject }.not_to change { Season.count }
        expect(subject).to eql next_season
      end
    end

    it 'creates the successor if it doesn\'t exist' do
      expect { subject }.to change { Season.count }.by(1)
      expect(subject.name).to eql (year+1).to_s
    end

    it 'sets the dates into the following year' do
      expect(subject.starts_at.year).to eql year+1
      expect(subject.ends_at.year).to eql year+1
      expect(subject.applications_open_at.year).to eql year+1
      expect(subject.applications_close_at.year).to eql year+1
    end
  end

  describe '.transition?' do
    subject { Season }

    context 'during mid-summer' do
      before { Timecop.travel Date.parse('2015-08-01') }
      it { is_expected.not_to be_transition }
    end

    context 'right after the summer has ended' do
      before { Timecop.travel Date.parse('2015-10-01') }
      it { is_expected.to be_transition }
    end

    context 'on New Year\'s' do
      before { Timecop.travel Date.parse('2016-01-01') }
      it { is_expected.not_to be_transition }
    end
  end

  describe '.projects_proposable?' do
    subject { described_class }

    context 'during transition phase' do
      context 'before project proposals open date' do
        before { Timecop.travel Date.parse('2015-11-15') }
        it { is_expected.not_to be_projects_proposable }
      end

      context 'after project proposals open date' do
        before { Timecop.travel Date.parse('2015-12-15') }
        it { is_expected.to be_projects_proposable }
      end
    end

    context 'at the beginning of a new year' do
      context 'after project proposals open date' do
        before { Timecop.travel Date.parse('2016-01-10') }
        it { is_expected.to be_projects_proposable }
      end
    end
  end

  ######## Testing Season Switch #############
  context 'switching phases' do
    describe '#fake_application_phase' do
      it 'timeshifts the application phase to today' do
        Timecop.travel(Season.current.applications_close_at - 1.month) do
          subject.fake_application_phase
          expect(subject).to be_application_period
        end
      end
    end

    describe '#fake_coding_phase' do
      it 'timeshifts the coding phase to today' do
        Timecop.travel(Season.current.ends_at - 1.week) do
          subject.fake_coding_phase
          expect(subject).to be_started
        end
      end
    end

    describe '#fake_proposals_phase' do
      it 'timeshifts the proposal period to today' do
        Timecop.travel(Season.current.project_proposals_close_at - 2.weeks) do
          fake_time = Time.now #as returned by Timecop
          subject.fake_proposals_phase
          expect(subject.project_proposals_open_at).to be < fake_time
          expect(subject.project_proposals_close_at).to be > fake_time
        end
      end
    end
  end

end