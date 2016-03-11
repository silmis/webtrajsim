import numpy as np
import matplotlib.pyplot as plt
import sys

def plot_speed():
	plt.figure()
	plt.plot(er['absTs'][1:], (np.diff(er['leader'])/np.diff(er['ts']/2.0)), '-k')
	plt.plot(er['absTs'], er['speedlim'], 'b')
	plt.show()

def plot_pos_by_segment():
	blocks = np.unique(er['segment'])
	
	for b in blocks:
		db = er[ er['segment'] == b ]
		plt.figure()
		plt.plot(db['absTs'], db['leader'], '-b')
		plt.plot(db['absTs'], db['player'], '-g')
		plt.title(b)
	plt.show()

def plot_speed_by_segment():
	blocks = np.unique(er['segment'])
	
	for b in blocks:
		db = er[ er['segment'] == b ]
		ts = db['ts'] / 2.0
		player_speed = np.diff(db['player']) / np.diff(ts)
		leader_speed = np.diff(db['leader']) / np.diff(ts)
		plt.figure()
		plt.plot(ts[1:], leader_speed, '-b')
		plt.plot(ts[1:], player_speed, '-g')
		plt.plot(ts, db['speedlim'], '-r')
		plt.title(b)
	plt.show()


paths = sys.argv[1:]
data = np.load(paths[0])
er = data[ data['experiment'] == 'easyRider' ]

#plot_speed()
#plot_pos_by_segment()
plot_speed_by_segment()
