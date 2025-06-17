// Object to store callbacks
const _channels = {};

export const subscribe = jest.fn((channel, replayId, onMessageCallback) => {
    _channels[channel] = { onMessageCallback };
    return Promise.resolve({
        id: '_1675854705834_7322',
        channel: channel,
        replayId: replayId
    });
});

export const jestMockPublish = jest.fn((channel, message) => {
    if (
        _channels[channel] &&
        _channels[channel].onMessageCallback instanceof Function
    ) {
        _channels[channel].onMessageCallback(message);
    }
    return Promise.resolve(true);
});

export const unsubscribe = jest.fn((subscription, callback)=>{
    console.log(subscription);
    callback(true);
    return Promise.resolve(true);
})