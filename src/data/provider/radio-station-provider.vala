/* This file is part of Gradio.
 *
 * Gradio is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Gradio is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Gradio.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gradio{

	public class StationProvider{
		public signal void finished();
		public signal void started();

		public signal void progress(double p);

		// Get the station data from ID
		public RadioStation parse_station_data_from_id (int id){
			Json.Parser parser = new Json.Parser ();
			RadioStation new_station = null;

			string data = Util.get_string_from_uri(RadioBrowser.radio_stations_by_id + id.to_string());
			try{
				if(data != ""){
					parser.load_from_data (data);
					var root = parser.get_root ();
					var radio_stations = root.get_array ();

					if(radio_stations.get_length() != 0){
						var radio_station = radio_stations.get_element(0);
						var radio_station_data = radio_station.get_object ();

						new_station = parse_station_data_from_json(radio_station_data);
					}
				}
			}catch (Error e){
				error("Parser: " + e.message);
			}

			return new_station;
		}


		// Parse the station data and return a station object
		private RadioStation parse_station_data_from_json (Json.Object radio_station_data){
			string title = radio_station_data.get_string_member("name");
			string homepage = radio_station_data.get_string_member("homepage");
			string language = radio_station_data.get_string_member("language");
			string id = radio_station_data.get_string_member("id");
			string icon = radio_station_data.get_string_member("favicon");
			string country = radio_station_data.get_string_member("country");
			string tags = radio_station_data.get_string_member("tags");
			string state = radio_station_data.get_string_member("state");
			string votes = radio_station_data.get_string_member("votes");
			string codec = radio_station_data.get_string_member("codec");
			string bitrate = radio_station_data.get_string_member("bitrate");
			bool broken;

			if(radio_station_data.get_string_member("lastcheckok") == "1")
				broken = false;
			else
				broken = true;

			RadioStation station = new RadioStation(title, homepage, language, id, icon, country, tags, state, votes, codec, bitrate, broken);
			return station;
		}


		public async int get_max_items(string address){
			SourceFunc callback = get_max_items.callback;
			int output = 1;

			ThreadFunc<void*> run = () => {
				try{
					string data = Util.get_string_from_uri(address);
					Json.Parser parser = new Json.Parser ();

					if(data != ""){
						parser.load_from_data (data);
						var root = parser.get_root ();
						var radio_stations = root.get_array ();

						output = (int)radio_stations.get_length();
					}
				}catch(GLib.Error e){
					warning(e.message);
				}

				Idle.add((owned) callback);
				Thread.exit (1.to_pointer ());
				return null;
			};

			new Thread<void*> ("search_thread", run);

			yield;
           		return output;
		}

		// Handle several stations and return them as a map
		public async List<RadioStation> get_radio_stations(string address, int start, int end) throws ThreadError{
			SourceFunc callback = get_radio_stations.callback;
			List<RadioStation> output = null;

			started();
			ThreadFunc<void*> run = () => {
				try{
		   			List<RadioStation> results = new List<RadioStation>();
					string data = Util.get_string_from_uri(address);
					Json.Parser parser = new Json.Parser ();

					if(data != ""){
						parser.load_from_data (data);
						var root = parser.get_root ();
						var radio_stations = root.get_array ();

						int max_items = (int)radio_stations.get_length();

						if(max_items < end)
							end = max_items;

						for(int a = start; a < end; a++){
							var radio_station = radio_stations.get_element(a);
							var radio_station_data = radio_station.get_object ();

							var station = parse_station_data_from_json(radio_station_data);

							double max_r = end;
							double actual_r = a;

							double p = actual_r/max_r;
							progress(p);

							results.append(station);
						}

						output = (owned)results;
					}else{
						output = null;
					}

				}catch(GLib.Error e){
					warning(e.message);
				}

				Idle.add((owned) callback);
				Thread.exit (1.to_pointer ());
				return null;
			};

			new Thread<void*> ("search_thread", run);

			yield;
			finished();
           		return output.copy();
        	}

	}

}
