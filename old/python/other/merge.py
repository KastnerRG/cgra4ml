import numpy as np
import cv2

HEIGHT = 720
WIDTH = 1280

out_1 = cv2.VideoWriter('day.avi', cv2.VideoWriter_fourcc(
    'M', 'J', 'P', 'G'), 10, (WIDTH, HEIGHT))
out_2 = cv2.VideoWriter('night.avi', cv2.VideoWriter_fourcc(
    'M', 'J', 'P', 'G'), 10, (WIDTH, HEIGHT))

path = 'videos/real/mov/converted/'
NUM_VIDEOS = 8

cap = []
for i in range(NUM_VIDEOS):
    cap += [cv2.VideoCapture(path+f'{i+1}.mp4')]

while(True):
    frames = []
    for i in range(NUM_VIDEOS):
        ret, frame = cap[i].read()

        if frame is None:
            continue
        H, W, C = frame.shape

        if i == 0:
            frames += [cv2.resize(frame[H//3:, W//3:, :],
                                  (WIDTH//2, HEIGHT//2))]
        if i == 1:
            frames += [cv2.resize(frame[H//3:, W//3:3*W //
                                        2, :], (WIDTH//2, HEIGHT//2))]
        if i == 2:
            frames += [cv2.resize(frame[H//5:, W//5:, :],
                                  (WIDTH//2, HEIGHT//2))]

        if i == 4:
            frames += [cv2.resize(frame[H//3:, W//3:, :],
                                  (WIDTH//2, HEIGHT//2))]
        if i == 5:
            frames += [cv2.resize(frame[H//3:, W//2:, :],
                                  (WIDTH//2, HEIGHT//2))]
        if i == 6:
            frames += [cv2.resize(frame[H//3:, W//3:, :],
                                  (WIDTH//2, HEIGHT//2))]
        if i == 7:
            frames += [cv2.resize(frame[H//3:, W//3:6*W //
                                        8, :], (WIDTH//2, HEIGHT//2))]

    # frame = np.zeros((HEIGHT, WIDTH, C))
    # frame[0:HEIGHT//2, 0:WIDTH//2, :] = frames[0]
    # frame[HEIGHT//2:, 0:WIDTH//2, :] = frames[1]
    # frame[0:HEIGHT//2, WIDTH//2:, :] = frames[2]
    # frame[HEIGHT//2:, WIDTH//2:, :] = frames[4]
    frame1 = np.concatenate([frames[0], frames[1]], axis=0)
    frame2 = np.concatenate([frames[2], frames[4]], axis=0)
    frame = np.concatenate([frame1, frame2], axis=1)

    out_1.write(frame)

    frame1 = np.concatenate([frames[5], frames[6]], axis=0)
    frame2 = np.concatenate([frames[6], frames[5]], axis=0)
    frame = np.concatenate([frame1, frame2], axis=1)

    out_2.write(frame)

    # H, W, C = frame.shape
    # print(frame.shape, frame[0:HEIGHT//2, 0:WIDTH//2, :].shape)

    # frame = frame[H//3:, W//3:6*W//8, :]
    # cv2.imshow('frame', frame)

    if cv2.waitKey(25) & 0xFF == ord('q'):
        break

for cap_i in cap:
    cap_i.release()
cv2.destroyAllWindows()
