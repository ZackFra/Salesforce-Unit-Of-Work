import { LightningElement, api } from 'lwc';

export default class Flow extends LightningElement {
    @api flowApiName;
    @api flowInputVariables;

    @api
    startFlow(flowApiName, flowInputVariables) {
        this.flowApiName = flowApiName;
        this.flowInputVariables = flowInputVariables;
    }
}