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

def windresistance():
	blocks = np.unique(er['segment'])
	run = er[ er['segment'] == blocks[0] ]
	speedlims = np.unique(run['speedlim'])

	difference = []
	for limit in speedlims:
		if limit is None:
			continue
		ld = run[ run['speedlim'] == limit ]
		ts = ld['ts'] / 2.0
		leader_speed = np.diff(ld['leader']) / np.diff(ts)
		diffspeed = np.diff(leader_speed)
		diffspeed = np.array(diffspeed)
		mask = (diffspeed > -0.001) & (diffspeed < 0.001)
		flatspeed = leader_speed[1:][mask]
		speedmean = np.mean(flatspeed)
		difference.append((limit, speedmean))

	limits, speeds = zip(*difference[1:])
	fit = np.polyfit(speeds, limits, 1)
	print fit
	
	plt.figure()
	plt.plot(limits, speeds)
	plt.show()	
	

paths = sys.argv[1:]
data = np.load(paths[0])
er = data[ data['experiment'] == 'easyRider' ]

plot_speed()
plot_pos_by_segment()
plot_speed_by_segment()
#windresistance()
