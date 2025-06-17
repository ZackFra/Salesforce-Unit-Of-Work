/*******************************************************************************************
 * @Name         logger.js
 * @Author       Vikas Patidar
 * @Description  THis is a JS Mock for Logger managed package componet used in JEST
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer                   Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Vikas Patidar             01/03/2022           Initial Creation
 *  1.1             Jai Aswani                01/19/2023           Added error and saveLog [17413]
 ******************************************************************************************
 */
import { LightningElement, api } from 'lwc';
    
export default class logger extends LightningElement {
  @api errors;
  @api notes;
  // any other implementation you may want to expose here
  @api
    error(){
        return
    }
    @api
    saveLog(){
        return
    }
    @api
    info(){
        return
    }
}
