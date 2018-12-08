class MARCModel < ASpaceExport::ExportModel
  model_for :marc21

  include JSONModel

#20160621LJD: Leader - Change u at position 18 with i for ISBD per technical services.
  def self.from_resource(obj, opts = {})
    marc = self.from_archival_object(obj, opts)
    marc.apply_map(obj, @resource_map)
    marc.leader_string = "00000np$aa2200000 i 4500"
    marc.leader_string[7] = obj.level == 'item' ? 'm' : 'c'

    marc.controlfield_string = assemble_controlfield_string(obj)

    marc
  end

#20160621LJD: 008 - Change 'xx' at positions 15-16 with 'mdu' for Maryland per technical services.
def self.assemble_controlfield_string(obj)
  date = obj.dates[0] || {}
  string = obj['system_mtime'].scan(/\d{2}/)[1..3].join('')
  string += obj.level == 'item' && date['date_type'] == 'single' ? 's' : 'i'
  string += date['begin'] ? date['begin'][0..3] : "    "
  string += date['end'] ? date['end'][0..3] : "    "
  string += "mdu"
  17.times { string += ' ' }
  string += (obj.language || '|||')
  string += ' d'

  string
end

#20160620LJD: 040 - Hard code JHE for 040 $a $e per technical services; add 'eng' to subfield b.
  def handle_repo_code(repository, langcode)
    repo = repository['_resolved']
    return false unless repo

    df('852', ' ', ' ').with_sfs(
                        ['a', 'The Johns Hopkins University'],
                        ['b', repo['name']],
                        ['e', '3400 N. Charles St. Baltimore, MD 21218']
                      )
    df('040', ' ', ' ').with_sfs(['a', 'JHE'], ['b', langcode], ['c', 'JHE'])
    df('049', ' ', ' ').with_sfs(['a', repo['org_code']])
  end

#20160621LJD: Change date from 245$f to 264$c per technical services.
  def handle_title(title, linked_agents, dates)
    creator = linked_agents.find{|a| a['role'] == 'creator'}
    date_codes = []

    # process dates first, if defined.
    unless dates.empty?
      dates = [["single", "inclusive", "range"], ["bulk"]].map {|types|
        dates.find {|date| types.include? date['date_type'] }
      }.compact

      dates.each do |date|
        code, val = nil
        code = date['date_type'] == 'bulk' ? 'g' : 'f'
        if date['expression']
          val = date['expression']
        elsif date['end']
          val = "#{date['begin']} - #{date['end']}"
        else
          val = "#{date['begin']}"
        end
        date_codes.push([code, val])
      end
    end

    ind1 = creator.nil? ? "0" : "1"
    df('245', ind1, '0').with_sfs(['a', title])

    if date_codes.length > 0
      # put dates in 264$c, but include only 245$f dates
      date_codes_264 = date_codes.select{|date| date[0] == 'f'}.map{|date| ['c', date[1]]}
      df('264', ' ', '0').with_sfs(*date_codes_264)
    end
  end

#20160620LJD: Prefercite incorrectly mapped to 534; changed to 524
  def handle_notes(notes)

    notes.each do |note|

      prefix =  case note['type']
                when 'dimensions'; "Dimensions"
                when 'physdesc'; "Physical Description note"
                when 'materialspec'; "Material Specific Details"
                when 'physloc'; "Location of resource"
                when 'phystech'; "Physical Characteristics / Technical Requirements"
                when 'physfacet'; "Physical Facet"
                when 'processinfo'; "Processing Information"
                when 'separatedmaterial'; "Materials Separated from the Resource"
                else; nil
                end

  #20160829LJD: Add additional note types for export.
      marc_args = case note['type']

                  when 'arrangement', 'fileplan'
                    ['351','b']
                  when 'odd', 'dimensions', 'physdesc', 'materialspec', 'physloc', 'phystech', 'physfacet', 'processinfo', 'separatedmaterial'
                    ['500','a']
                  when 'accessrestrict'
                    ['506','a']
                  when 'scopecontent'
                    ['520', '2', ' ', 'a']
                  when 'abstract'
                    ['520', '3', ' ', 'a']
                  when 'prefercite'
                    ['524', '8', ' ', 'a']
                  when 'acqinfo'
                    ind1 = note['publish'] ? '1' : '0'
                    ['541', ind1, ' ', 'a']
                  when 'relatedmaterial'
                    ['544','a']
                  when 'bioghist'
                    ['545','a']
                  when 'custodhist'
                    ind1 = note['publish'] ? '1' : '0'
                    ['561', ind1, ' ', 'a']
                  when 'appraisal'
                    ind1 = note['publish'] ? '1' : '0'
                    ['583', ind1, ' ', 'a']
                  when 'accruals'
                    ['584', 'a']
                  when 'altformavail'
                    ['535', '2', ' ', 'a']
                  when 'originalsloc'
                    ['535', '1', ' ', 'a']
                  when 'userestrict', 'legalstatus'
                    ['540', 'a']
                  when 'langmaterial'
                    ['546', 'a']
                  else
                    nil
                  end

      unless marc_args.nil?
        text = prefix ? "#{prefix}: " : ""
        text += ASpaceExport::Utils.extract_note_text(note)
        df!(*marc_args[0...-1]).with_sfs([marc_args.last, *Array(text)])
      end

    end
  end

end
